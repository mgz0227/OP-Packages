'use strict';
'require form';
'require poll';
'require rpc';
'require uci';
'require view';

var callServiceList = rpc.declare({
	object: 'service',
	method: 'list',
	params: ['name'],
	expect: { '': {} }
});

function getServiceStatus() {
	return L.resolveDefault(callServiceList('dufs'), {}).then(function (res) {
		var isRunning = false;
		try {
			isRunning = res['dufs']['instances']['dufs']['running'];
		} catch (e) { }
		return isRunning;
	});
}

function renderStatus(isRunning, port, path) {
	var spanTemp = '<em><span style="color:%s"><strong>%s %s</strong></span></em>';
	var renderHTML;
	if (isRunning) {
		var dufsURL = '//' + window.location.hostname + ':' + port + '/' + path.replace(/^\//, '');
		var button = String.format('&#160;<a class="btn cbi-button" href="%s" target="_blank" rel="noreferrer noopener">%s</a>',
			dufsURL, _('Open Web Interface'));
		renderHTML = spanTemp.format('green', _('Dufs'), _('RUNNING')) + button;
	} else {
		renderHTML = spanTemp.format('red', _('Dufs'), _('NOT RUNNING'));
	}

	return renderHTML;
}

return view.extend({
	load: function() {
		return Promise.all([
			uci.load('dufs')
		]);
	},

	render: function(data) {
		var m, s, o;
		var webport = uci.get(data[0], 'config', 'port') || '5244';
		var webpath = uci.get(data[0], 'config', 'path_prefix') || '/';

		m = new form.Map('dufs', _('Dufs'),
			_('Dufs is a distinctive utility file server that supports static serving, uploading, searching, accessing control, webdav...'));

		s = m.section(form.TypedSection);
		s.anonymous = true;
		s.render = function () {
			poll.add(function () {
				return L.resolveDefault(getServiceStatus()).then(function (res) {
					var view = document.getElementById('service_status');
					view.innerHTML = renderStatus(res, webport, webpath);
				});
			});

			return E('div', { class: 'cbi-section', id: 'status_bar' }, [
				E('p', { id: 'service_status' }, _('Collecting data…'))
			]);
		}

		s = m.section(form.NamedSection, 'config', 'dufs');

		o = s.option(form.Flag, 'enabled', _('Enable'));
		o.default = o.disabled;
		o.rmempty = false;

		o = s.option(form.Value, 'bind', _('Listen address'));
		o.datatype = 'ipaddr(1)';

		o = s.option(form.Value, 'port', _('Listen port'));
		o.datatype = 'port';
		o.placeholder = '5000';

		o = s.option(form.Value, 'path_prefix', _('Path Prefix'),
			_('Specify a (URL) path prefix'));
		o.placeholder = 'dufs';

		o = s.option(form.Flag, 'enable_cors', _('Enable CORS'));

		o = s.option(form.Flag, 'internet', _('Allow access from Internet'));

		o = s.option(form.Value, 'serve_path', _('Serve path'));
		o.placeholder = '/mnt';

		o = s.option(form.DynamicList, 'hidden', _('Hidden path'),
			_('Hide paths from directory listings, e.g. %s.').format('<code>tmp,*.log,*.lock</code>'));

		o = s.option(form.DynamicList, 'auth', _('Auth roles'),
			_('Add auth roles, e.g. %s.').format('<code>user:pass@/dir1:rw,/dir2</code>'));

		o = s.option(form.Flag, 'render_index', _('Render index'),
			_('Serve index.html when requesting a directory, returns 404 if not found index.html.'));
		o.depends('render_try_index', '0');

		o = s.option(form.Flag, 'render_try_index', _('Render index or directory list'),
			_('Serve index.html when requesting a directory, returns directory listing if not found index.html.'));
		o.default = o.enabled;

		o = s.option(form.Flag, 'allow_all', _('Allow all operations'));

		o = s.option(form.Flag, 'allow_upload', _('Allow upload files/folders'));
		o.depends('allow_all', '0');

		o = s.option(form.Flag, 'allow_delete', _('Allow delete files/folders'));
		o.depends('allow_all', '0');

		o = s.option(form.Flag, 'allow_search', _('Allow search files/folders'));
		o.depends('allow_all', '0');

		o = s.option(form.Flag, 'allow_symlink', _('Allow symlink to files/folders outside root directory'));
		o.depends('allow_all', '0');

		o = s.option(form.Flag, 'allow_archive', _('Allow zip archive generation'));
		o.depends('allow_all', '0');

		o = s.option(form.ListValue, 'compress', _('Zip compression level'));
		o.value('none', _('None'));
		o.value('low', _('Low'));
		o.value('medium', _('Medium'));
		o.value('high', _('High'));
		o.default = 'none';
		o.depends('allow_all', '1');
		o.depends('allow_archive', '1');

		return m.render();
	}
});
