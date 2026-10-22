//go:build linux && openwrt

package agent

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/coreos/go-systemd/v22/dbus"
	"github.com/henrygd/beszel/agent/utils"
	"github.com/henrygd/beszel/internal/entities/systemd"
)

var errNoActiveTime = errors.New("no active time")

type systemdManager struct {
	sync.Mutex
	serviceStatsMap map[string]*systemd.Service
	isRunning       bool
	hasFreshStats   bool
	patterns        []string
	logsEnabled     bool
}

func isSystemdAvailable() bool {
	return true
}

func newSystemdManager() (*systemdManager, error) {
	if skipSystemd, _ := utils.GetEnv("SKIP_SYSTEMD"); skipSystemd == "true" {
		return nil, nil
	}

	manager := &systemdManager{
		serviceStatsMap: make(map[string]*systemd.Service),
		patterns:        getServicePatterns(),
	}

	manager.startWorker(nil)

	return manager, nil
}

func (sm *systemdManager) startWorker(conn *dbus.Conn) {
	if sm.isRunning {
		return
	}
	sm.isRunning = true
	_ = sm.getServiceStats(nil, true)
	go func() {
		for {
			time.Sleep(time.Minute * 10)
			_ = sm.getServiceStats(nil, true)
		}
	}()
}

func (sm *systemdManager) getServiceStatsCount() int {
	return len(sm.serviceStatsMap)
}

func (sm *systemdManager) getFailedServiceCount() uint16 {
	return 0 
}

func (sm *systemdManager) getServiceStats(conn *dbus.Conn, refresh bool) []*systemd.Service {
	var services []*systemd.Service

	if !refresh {
		sm.Lock()
		defer sm.Unlock()
		for _, service := range sm.serviceStatsMap {
			services = append(services, service)
		}
		sm.hasFreshStats = false
		return services
	}

	out, err := exec.Command("ubus", "call", "service", "list").Output()
	if err != nil {
		return nil
	}

	type UbusInstance struct {
		Running bool `json:"running"`
		Pid     int  `json:"pid"`
	}
	type UbusService struct {
		Instances map[string]UbusInstance `json:"instances"`
	}

	var ubusData map[string]UbusService
	if err := json.Unmarshal(out, &ubusData); err != nil {
		return nil
	}

	currentUnits := make(map[string]struct{})
	pageSize := uint64(os.Getpagesize())
	if pageSize == 0 {
		pageSize = 4096
	}

	sm.Lock()
	defer sm.Unlock()

	for sName, sData := range ubusData {
		unitName := sName + ".service"
		currentUnits[unitName] = struct{}{}

		pid := 0
		isRunning := false
		for _, inst := range sData.Instances {
			if inst.Running && inst.Pid > 0 {
				pid = inst.Pid
				isRunning = true
				break
			}
		}

		service, exists := sm.serviceStatsMap[unitName]
		if !exists {
			service = &systemd.Service{Name: sName}
			sm.serviceStatsMap[unitName] = service
		}

		if isRunning {
			service.State = systemd.ParseServiceStatus("active")
			service.Sub = systemd.ParseServiceSubState("running")

			if data, err := os.ReadFile(fmt.Sprintf("/proc/%d/stat", pid)); err == nil {
				binEnd := strings.LastIndex(string(data), ")")
				if binEnd != -1 && len(string(data)) > binEnd+2 {
					fields := strings.Fields(string(data)[binEnd+2:])
					if len(fields) > 21 {
						utime, _ := strconv.ParseUint(fields[11], 10, 64)
						stime, _ := strconv.ParseUint(fields[12], 10, 64)
						rss, _ := strconv.ParseUint(fields[21], 10, 64)

						service.Mem = rss * pageSize
						if service.Mem > service.MemPeak {
							service.MemPeak = service.Mem
						}
						service.UpdateCPUPercent((utime + stime) * 10000000)
					}
				}
			}
		} else {
			service.State = systemd.ParseServiceStatus("active")
			service.Sub = systemd.ParseServiceSubState("exited")
			service.Mem = 0
			service.UpdateCPUPercent(0)
		}
		services = append(services, service)
	}

	for unitName := range sm.serviceStatsMap {
		if _, exists := currentUnits[unitName]; !exists {
			delete(sm.serviceStatsMap, unitName)
		}
	}

	sm.hasFreshStats = true
	return services
}

func (sm *systemdManager) updateServiceStats(conn *dbus.Conn, unit dbus.UnitStatus) (*systemd.Service, error) {
	return nil, nil
}

func (sm *systemdManager) getServiceDetails(serviceName string) (systemd.ServiceDetails, error) {
	details := make(systemd.ServiceDetails)
	uName := strings.TrimSuffix(serviceName, ".service")
	initScript := "/etc/init.d/" + uName

	// 1. Get cache data (used to obtain historical memory peaks)
	sm.Lock()
	service, exists := sm.serviceStatsMap[serviceName]
	if !exists {
		service, exists = sm.serviceStatsMap[uName]
	}
	sm.Unlock()

	// Initialize the default value
	details["ActiveState"] = "inactive"
	details["SubState"] = "dead"
	details["Result"] = "success"
	details["MemoryCurrent"] = uint64(0)
	details["MemoryPeak"] = uint64(0)
	details["MainPID"] = uint64(0)
	details["TasksCurrent"] = uint64(0)

	// 2. Real-time query Ubus to get the status, PID, number of concurrent threads and memory RSS
	var isLoadedInProcd bool = false
	var isRunningRealTime bool = false
	var currentMem uint64 = 0

	out, err := exec.Command("ubus", "call", "service", "list", fmt.Sprintf(`{"name":"%s"}`, uName)).Output()
	if err == nil {
		type UbusInstance struct {
			Running bool `json:"running"`
			Pid     int  `json:"pid"`
		}
		type UbusService struct {
			Instances map[string]UbusInstance `json:"instances"`
		}
		var ubusData map[string]UbusService
		if json.Unmarshal(out, &ubusData) == nil {
			if sData, ok := ubusData[uName]; ok {
				isLoadedInProcd = true
				for _, inst := range sData.Instances {
					if inst.Running {
						isRunningRealTime = true
						if inst.Pid > 0 {
							details["MainPID"] = uint64(inst.Pid)

							// Accurate real-time reading of memory (RSS)
							if data, err := os.ReadFile(fmt.Sprintf("/proc/%d/stat", inst.Pid)); err == nil {
								binEnd := strings.LastIndex(string(data), ")")
								if binEnd != -1 && len(string(data)) > binEnd+2 {
									fields := strings.Fields(string(data)[binEnd+2:])
									if len(fields) > 21 {
										pageSize := uint64(os.Getpagesize())
										if pageSize == 0 {
											pageSize = 4096
										}
										rss, _ := strconv.ParseUint(fields[21], 10, 64)
										currentMem = rss * pageSize
									}
								}
							}

							// Accurately read the number of threads in real time (Tasks)
							if data, err := os.ReadFile(fmt.Sprintf("/proc/%d/status", inst.Pid)); err == nil {
								lines := strings.Split(string(data), "\n")
								for _, line := range lines {
									if strings.HasPrefix(line, "Threads:") {
										fields := strings.Fields(line)
										if len(fields) >= 2 {
											tasks, _ := strconv.ParseUint(fields[1], 10, 64)
											details["TasksCurrent"] = tasks
										}
										break
									}
								}
							}
							break
						}
					}
				}
			}
		}
	}

	// 3. Core indicator status calibration and memory peak calculation
	if isRunningRealTime {
		details["ActiveState"] = "active"
		details["SubState"] = "running"
		details["MemoryCurrent"] = currentMem
		
		if exists && service.MemPeak > currentMem {
			details["MemoryPeak"] = service.MemPeak
		} else {
			details["MemoryPeak"] = currentMem
		}
	} else if isLoadedInProcd {
		details["ActiveState"] = "active"
		details["SubState"] = "exited"
		details["MemoryCurrent"] = uint64(0)
		if exists { details["MemoryPeak"] = service.MemPeak }
	} else {
		details["ActiveState"] = "inactive"
		details["SubState"] = "dead"
		details["MemoryCurrent"] = uint64(0)
		if exists { details["MemoryPeak"] = service.MemPeak }
	}

	// 4. Complete Systemd-compatible metadata
	details["Id"] = serviceName
	details["Description"] = uName + " (OpenWrt Procd)"
	details["LoadState"] = "loaded"
	details["FragmentPath"] = initScript
	details["NRestarts"] = uint64(0)
	details["StatusText"] = ""

	// Check the self-starting status of the service
	unitFileState := "disabled"
	if info, err := os.Stat(initScript); err == nil && !info.Mode().IsDir() {
		if err := exec.Command(initScript, "enabled").Run(); err == nil {
			unitFileState = "enabled"
		}
	}
	details["UnitFileState"] = unitFileState

	// Dynamic detection service control capability (Capabilities)
	canStart, canStop, canReload := false, false, false
	if info, err := os.Stat(initScript); err == nil && !info.Mode().IsDir() {
		ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
		defer cancel()
		out, _ := exec.CommandContext(ctx, initScript).CombinedOutput()
		outputStr := strings.ToLower(string(out))
		if strings.Contains(outputStr, "start") { canStart = true }
		if strings.Contains(outputStr, "stop") { canStop = true }
		if strings.Contains(outputStr, "reload") { canReload = true }
	}
	details["CanStart"] = canStart
	details["CanStop"] = canStop
	details["CanReload"] = canReload

	return details, nil
}

func unescapeServiceName(name string) string {
	return name
}

func getServicePatterns() []string {
	patterns := []string{}
	if envPatterns, _ := utils.GetEnv("SERVICE_PATTERNS"); envPatterns != "" {
		for pattern := range strings.SplitSeq(envPatterns, ",") {
			pattern = strings.TrimSpace(pattern)
			if pattern == "" {
				continue
			}
			if !strings.HasSuffix(pattern, "timer") && !strings.HasSuffix(pattern, ".service") {
				pattern += ".service"
			}
			patterns = append(patterns, pattern)
		}
	}
	if len(patterns) == 0 {
		patterns = []string{"*.service"}
	}
	return patterns
}

func (sm *systemdManager) getServiceLogs(serviceName string) ([]byte, error) {
	/* 
	   未来进阶提示：如果你想在前端也看到 OpenWrt 的服务日志，
	   可以将 serviceName 去掉后缀，然后通过执行类似以下的命令返回真实的日志字节流：
	   out, err := exec.Command("logread", "-e", strings.TrimSuffix(serviceName, ".service")).Output()
	   return out, err
	*/
	return nil, nil
}
