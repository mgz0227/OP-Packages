'use strict';

'require dom';
'require fs';
'require form';
'require poll';
'require rpc';
'require view';

const POLL_INTERVAL = 5;

function getServiceInfo(name) {
	const fn = rpc.declare({
		object: 'service',
		method: 'list',
		params: ['name'],
		expect: { [name]: {} },
	});
	return () => fn(name);
}

const getBoardInfo = rpc.declare({
	object: 'system',
	method: 'board',
});

const getBeszelAgentInfo = getServiceInfo('beszel-agent');

async function getStatus() {
	try {
		const res = await getBeszelAgentInfo();
		const isRunning = res?.instances?.['beszel-agent']?.running;
		return isRunning ?? false;
	} catch (e) {
		console.error(e);
		return false;
	}
}

async function getVersion() {
	try {
		const res = await fs.exec('/usr/bin/beszel-agent', ['-v']);
		if (res && res.code === 0 && res.stdout) {
			const match = res.stdout.match(/(\d+\.\d+\.\d+)/);
			return match ? match[0] : res.stdout.trim();
		}
		return _('Unknown');
	} catch (e) {
		console.error(e);
		return _('Unknown');
	}
}

function getStatusValue(isRunning) {
	const runningSpan = `<span style="color: green; font-weight: bold">${_('Running')}</span>`;
	const notRunningSpan = `<span style="color: red; font-weight: bold">${_('Not running')}</span>`;
	return isRunning ? runningSpan : notRunningSpan;
}

function updateStatus(node) {
	const output = node?.querySelector('output');
	return output
		? async () => {
			const isRunning = await getStatus();
			dom.content(output, getStatusValue(isRunning));
		}
		: () => {};
}

return view.extend({
	load() {
		return Promise.all([
			getStatus(),
			getVersion(),
			getBoardInfo().catch(() => ({})),
			fs.list('/sys/class/drm').catch(() => []),
		]);
	},

	async render([isRunning, versionText, boardInfo, drmList]) {
		const target = boardInfo?.release?.target || '';
		const isX86 = target.startsWith('x86');
		const hasCardNode = drmList && drmList.some(item => /^card\d+$/.test(item.name));
		const showGpuOptions = isX86 && hasCardNode;

		const map = new form.Map('beszel-agent', _('Beszel Agent'),
			_('Lightweight telemetry agent for reporting system and Docker metrics to your Beszel Hub.'));

		const statusSect = map.section(form.TypedSection, 'status');
		statusSect.anonymous = true;
		statusSect.cfgsections = () => ['status_section'];

		const versionOpt = statusSect.option(form.DummyValue, '_version', _('Version'));
		versionOpt.cfgvalue = () => versionText;

		const statusOpt = statusSect.option(form.DummyValue, '_status', _('Service Status'));
		statusOpt.rawhtml = true;
		statusOpt.cfgvalue = () => getStatusValue(isRunning);

		const mainSect = map.section(form.TypedSection, 'beszel-agent');
		mainSect.anonymous = true;
		mainSect.addremove = false;

		mainSect.tab('general', _('General Settings'));
		mainSect.tab('network', _('Network Settings'), _('Configure network interface monitoring rules.'));
		mainSect.tab('mounts', _('Extra Disks'), _('Configure extra disks for Beszel Agent to monitor.'));
		mainSect.tab('other', _('Other Settings'), _('Advanced and others configurations.'));

		const enableOpt = mainSect.taboption('general', form.Flag, 'enable', _('Enable'));
		enableOpt.default = '0';
		enableOpt.rmempty = false;

		const sysNameOpt = mainSect.taboption('general', form.Value, 'system_name', _('System Name'), 
			_('Override system name on universal token registration.<br>Defaults to hostname if unset.'));
		sysNameOpt.placeholder = 'OpenWrt';
		sysNameOpt.rmempty = true;

		const listenOpt = mainSect.taboption('general', form.Value, 'listen', _('Listen'), 
			_('IP address, port, or unix socket<br>(e.g., 0.0.0.0:45876 or [::]:45876). Replaces Port.'));
		listenOpt.placeholder = '0.0.0.0:45876';
		listenOpt.rmempty = true;

		const portOpt = mainSect.taboption('general', form.Value, 'port', _('Port (Deprecated)'), 
			_('Maintained for backward compatibility.<br>Will be cleared if Listen is configured.'));
		portOpt.datatype = 'port';
		portOpt.default = '45876';
		portOpt.placeholder = '45876';
		portOpt.rmempty = true;
		portOpt.write = function(section_id, formvalue) {
			const listenVal = this.section.formvalue(section_id, 'listen');
			if (listenVal && listenVal.trim() !== '') {
				return this.super('remove', [section_id]);
			}
			return this.super('write', [section_id, formvalue]);
		};

		const hubOpt = mainSect.taboption('general', form.Value, 'hub_url', _('Hub URL'), _('The URL of your Beszel Hub.'));
		hubOpt.placeholder = 'http://hub.example.com:8090';
		hubOpt.attrs = { autocomplete: 'off' };
		hubOpt.rmempty = false;
		hubOpt.validate = (section_id, value) => {
			if (!value)
				return true;

			// scheme (required) + host (IPv4 / IPv6 / hostname) + optional port + optional path
			const urlPattern = /^https?:\/\/(\[[0-9a-fA-F:]+\]|[a-zA-Z0-9.-]+)(:\d{1,5})?(\/[^\s]*)?$/;
			return urlPattern.test(value)
				? true
				: _('Must be a valid URL, e.g. http://hub.example.com:8090');
		};

		const keyOpt = mainSect.taboption('general', form.Value, 'key', _('Public Key'), _('Public SSH key (if using SSH-based auth).'));
		keyOpt.placeholder = 'ssh-ed25519 ...';
		keyOpt.rmempty = false;

		const tokenOpt = mainSect.taboption('general', form.Value, 'token', _('Token'), _('Authentication token (if using token-based auth).'));
		tokenOpt.password = true;
		tokenOpt.rmempty = false;

		// --- Network Settings  ---
		const nicsOpt = mainSect.taboption('network', form.DynamicList, 'nics', _('Interface Filters (NICS)'),
			_('Specify network interfaces to monitor or exclude.<br>Prefix with "-" to blacklist (e.g., "-phy*", "-*ap*").<br>Leave empty to use default filtering.'));
		nicsOpt.placeholder = '-phy*';

		// --- Extra Disks  ---
		const extraFsOpt = mainSect.taboption('mounts', form.DynamicList, 'extra_filesystems', _('Extra Filesystems'),
			_('Specify additional mount points to monitor (e.g., /mnt/sda1).'));
		extraFsOpt.placeholder = '/mnt/sda1';
		extraFsOpt.validate = (section_id, value) => (!value || value.startsWith('/')) ? true : _('Path must be absolute (must start with /).');

		// --- Other Settings  ---
		const bootDelayOpt = mainSect.taboption('other', form.Value, 'boot_delay', _('Boot Delay'),
			_('Delay in seconds before starting the agent on system boot to allow network and DNS to settle. Defaults to 15 if unset.'));
		bootDelayOpt.datatype = 'uinteger';
		bootDelayOpt.default = '15';
		bootDelayOpt.placeholder = '15';
		bootDelayOpt.rmempty = true;

		const dataDirOpt = mainSect.taboption('other', form.Value, 'data_dir', _('Data Directory'),
			_('Directory to store system fingerprint and local data. Defaults to /etc/beszel-agent if unset.'));
		dataDirOpt.placeholder = '/etc/beszel-agent';
		dataDirOpt.default = '/etc/beszel-agent';
		dataDirOpt.rmempty = true;

		const logLevelOpt = mainSect.taboption('other', form.ListValue, 'log_level', _('Log Level'));
		logLevelOpt.default = 'info';
		logLevelOpt.value('debug', _('Debug'));
		logLevelOpt.value('info', _('Info'));
		logLevelOpt.value('warn', _('Warn'));
		logLevelOpt.value('error', _('Error'));

		if (showGpuOptions) {
			const skipGpuOpt = mainSect.taboption('other', form.ListValue, 'skip_gpu', _('Skip GPU'),
				_('(True) to Disable GPU monitoring.'));
			skipGpuOpt.default = 'false';
			skipGpuOpt.value('true', _('True'));
			skipGpuOpt.value('false', _('False'));

			const gpuCollOpt = mainSect.taboption('other', form.ListValue, 'gpu_collector', _('GPU Collector'),
				_('If Agent fails automatically detect it, please choose one according to your GPU.'));
			gpuCollOpt.value('', _('Auto Detect (Default)'));
			gpuCollOpt.value('intel_gpu_top', _('Intel GPUs'));
			gpuCollOpt.value('amd_sysfs', _('AMD GPUs'));
			gpuCollOpt.depends('skip_gpu', 'false');

			const gpuDevOpt = mainSect.taboption('other', form.Value, 'intel_gpu_device', _('Intel GPU Device'), 
				_('Specify the device name (e.g., card0). Defaults to card0 if unset.'));
			gpuDevOpt.placeholder = 'card0';
			gpuDevOpt.rmempty = true;
			gpuDevOpt.depends({ skip_gpu: 'false', gpu_collector: 'intel_gpu_top' });
		}

		const skipSystemdOpt = mainSect.taboption('other', form.ListValue, 'skip_systemd', _('Skip Systemd'),
			_('(True) to Disable Systemd service monitoring.'));
		skipSystemdOpt.default = 'false';
		skipSystemdOpt.value('true', _('True'));
		skipSystemdOpt.value('false', _('False'));

		const dockerHostOpt = mainSect.taboption('other', form.Value, 'docker_host', _('Docker HOST'),
			_('Overrides the Docker host (docker.sock).<br>Leave empty to completely disable Docker monitoring.'));
		dockerHostOpt.rmempty = true;

		const rendered = await map.render();

		const style = document.createElement('style');
		style.innerHTML = '.hide-agent-ui { display: none !important; }';
		rendered.appendChild(style);

		const enableRow = rendered.querySelector('.cbi-value[id$="-enable"]');
		const listenRow = rendered.querySelector('.cbi-value[id$="-listen"]');
		const portRow = rendered.querySelector('.cbi-value[id$="-port"]');
		const hubRow = rendered.querySelector('.cbi-value[id$="-hub_url"]');
		const tokenRow = rendered.querySelector('.cbi-value[id$="-token"]');
		const keyRow = rendered.querySelector('.cbi-value[id$="-key"]');

		if (enableRow && hubRow && tokenRow && keyRow && (listenRow || portRow)) {
			const fieldContainer = enableRow.querySelector('.cbi-value-field');
			const listenInput = listenRow ? listenRow.querySelector('input') : null;
			const portInput = portRow ? portRow.querySelector('input') : null;
			const hubInput = hubRow.querySelector('input');
			const tokenInput = tokenRow.querySelector('input');
			const keyInput = keyRow.querySelector('input');

			if (listenInput && portInput && portRow) {
				function handleListenVisibility() {
					const hasListen = listenInput.value.trim() !== '';
					if (hasListen) {
						if (portInput.value !== '') {
							portInput.value = '';
							portInput.dispatchEvent(new Event('input', { bubbles: true }));
						}
						portRow.style.display = 'none';
					} else {
						portRow.style.display = '';
					}
				}
				listenInput.addEventListener('input', handleListenVisibility);
				handleListenVisibility();
				portInput.addEventListener('input', () => {
					if (portInput.value.trim() !== '' && listenInput.value !== '') {
						listenInput.value = '';
						listenInput.dispatchEvent(new Event('input', { bubbles: true }));
						handleListenVisibility(); 
					}
				});
			}

			if (fieldContainer && portInput && hubInput && tokenInput && keyInput) {
				const warningNode = document.createElement('div');
				warningNode.style.color = '#ff9800';
				warningNode.style.fontWeight = 'bold';
				warningNode.style.paddingTop = '6px';
				warningNode.innerHTML = '💡 ' + _('Please configure Port, Hub URL, Token, and Public Key to enable.');
				fieldContainer.prepend(warningNode);

				function updateEnableUI() {
					const hasListen = listenInput && listenInput.value.trim().length > 0;
					const hasPort = portInput && portInput.value.trim().length > 0;
					const hasHub = hubInput.value.trim().length > 0;
					const hasToken = tokenInput.value.trim().length > 0;
					const hasKey = keyInput.value.trim().length > 0;
					
					const missing = [];
					if (!hasListen && !hasPort) missing.push(_('Listen (or Port)'));
					if (!hasHub) missing.push(_('Hub URL'));
					if (!hasToken) missing.push(_('Token'));
					if (!hasKey) missing.push(_('Public Key'));

					const isValid = missing.length === 0;

					if (!isValid) {
						let missingText = '';
						if (missing.length === 1) {
							missingText = missing[0];
						} else {
							const last = missing.pop();
							missingText = missing.join(', ') + ' ' + _('and') + ' ' + last;
						}
						warningNode.innerHTML = '💡 ' + _('Please configure %s to enable.').replace('%s', missingText);
					}

					if (!isValid) {
						const cb = fieldContainer.querySelector('input[type="checkbox"]');
						if (cb && cb.checked) {
							cb.checked = false;
							cb.dispatchEvent(new Event('change', { bubbles: true }));
						}
					}

					Array.from(fieldContainer.children).forEach(child => {
						if (child === warningNode) {
							child.style.display = isValid ? 'none' : 'block';
						} else {
							if (isValid) child.classList.remove('hide-agent-ui');
							else child.classList.add('hide-agent-ui');
						}
					});
				}
				const inputs = [listenInput, portInput, hubInput, tokenInput, keyInput].filter(Boolean);
				inputs.forEach(inp => {
					inp.addEventListener('input', updateEnableUI);
					inp.addEventListener('change', updateEnableUI);
				});
				updateEnableUI();
			}
		}

		const statusNode = map.findElement('data-field', statusOpt.cbid('status_section'));
		if (statusNode) poll.add(updateStatus(statusNode), POLL_INTERVAL);

		return rendered;
	},
});
