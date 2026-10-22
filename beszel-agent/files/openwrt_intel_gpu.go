//go:build linux && openwrt

package agent

import (
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/henrygd/beszel/internal/entities/system"
)

const intelGpuStatsCmd = "sh"

type intelGpuStats struct {
	PowerGPU float64
	PowerPkg float64
	Engines  map[string]float64
}

var (
	gpuStateMu sync.Mutex
	lastRc6 uint64
	lastGpuEnergy uint64
	lastPkgEnergy uint64
	lastTime time.Time
)

func getEnergyPaths() (gpuPath string, pkgPath string) {
	pkgBase := "/sys/class/powercap/intel-rapl/intel-rapl:0"
	gpuBase := "/sys/class/powercap/intel-rapl/intel-rapl:0/intel-rapl:0:1"

	if _, err := os.Stat(pkgBase + "/energy_uj"); err == nil {
		pkgPath = pkgBase + "/energy_uj"
	}
	if _, err := os.Stat(gpuBase + "/energy_uj"); err == nil {
		gpuPath = gpuBase + "/energy_uj"
	}
	return gpuPath, pkgPath
}

func readUint64(path string) uint64 {
	if path == "" {
		return 0
	}
	data, err := os.ReadFile(path)
	if err != nil {
		return 0
	}
	val, _ := strconv.ParseUint(strings.TrimSpace(string(data)), 10, 64)
	return val
}

func (gm *GPUManager) updateIntelFromStats(sample *intelGpuStats) bool {
	gm.Lock()
	defer gm.Unlock()

	id := "0"
	gpuData, ok := gm.GpuDataMap[id]
	if !ok {
		gpuData = &system.GPUData{Name: "GPU", Engines: make(map[string]float64)}
		gm.GpuDataMap[id] = gpuData
	}

	gpuData.Power += sample.PowerGPU
	gpuData.PowerPkg += sample.PowerPkg

	if gpuData.Engines == nil {
		gpuData.Engines = make(map[string]float64, len(sample.Engines))
	}
	for name, engine := range sample.Engines {
		gpuData.Engines[name] += engine
	}

	gpuData.Count++
	return true
}

func (gm *GPUManager) collectIntelStats() (err error) {
	gpuStateMu.Lock()
	defer gpuStateMu.Unlock()

	device := os.Getenv("INTEL_GPU_DEVICE")
	if device == "" {
		device = "card0"
	}
	device = filepath.Base(device)

	rc6Path := "/sys/class/drm/" + device + "/power/rc6_residency_ms"
	gpuEnergyPath, pkgEnergyPath := getEnergyPaths()

	currRc6 := readUint64(rc6Path)
	currGpuEnergy := readUint64(gpuEnergyPath)
	currPkgEnergy := readUint64(pkgEnergyPath)

	now := time.Now()
	
	if !lastTime.IsZero() {
		timeDelta := uint64(now.Sub(lastTime).Milliseconds())
		if timeDelta > 500 {
			rc6Delta := currRc6 - lastRc6
			usage := 100.0 - (float64(rc6Delta) / float64(timeDelta) * 100.0)
			if usage < 0 { usage = 0 }

			var powerGPU float64
			if currGpuEnergy > 0 && currGpuEnergy >= lastGpuEnergy {
				energyDelta := currGpuEnergy - lastGpuEnergy
				powerGPU = float64(energyDelta) / float64(timeDelta) / 1000.0
			}

			var powerPkg float64
			if currPkgEnergy > 0 && currPkgEnergy >= lastPkgEnergy {
				energyDelta := currPkgEnergy - lastPkgEnergy
				powerPkg = float64(energyDelta) / float64(timeDelta) / 1000.0
			}

			sample := intelGpuStats{
				PowerGPU: powerGPU,
				PowerPkg: powerPkg,
				Engines: map[string]float64{
					"Render/3D": usage,
				},
			}
			gm.updateIntelFromStats(&sample)
		}
	}

	lastRc6 = currRc6
	lastGpuEnergy = currGpuEnergy
	lastPkgEnergy = currPkgEnergy
	lastTime = now
	time.Sleep(2 * time.Second)

	return nil
}
