/*
 Document pipeline — prepare the SharePoint site.

 Checks that the library exists (it is NEVER created here), creates the watched folder inside it,
 and creates the results list with the columns the pipeline writes. Re-running is safe.

 HOW TO RUN
   1. Open __SITE_URL__ in Chrome/Edge (any page on the site).
   2. Press F12 -> Console tab.
   3. Paste this whole file and press Enter.
   4. Wait for "ALL DONE".

 The three values below are filled in by grant-graph.ps1 from env/<name>.json.
*/
(async () => {
  const LIBRARY = '__LIBRARY__';        // display name of an existing document library
  const FOLDER = '__FOLDER__';          // folder inside it to watch; created if missing
  const RESULTS_LIST = '__RESULTS_LIST__';

  const site = (window._spPageContextInfo && _spPageContextInfo.webAbsoluteUrl) || location.origin + location.pathname.replace(/\/SitePages.*$|\/_layouts.*$/i, '');
  const V = 'application/json;odata=verbose';
  const digest = (await (await fetch(site + '/_api/contextinfo', { method: 'POST', headers: { Accept: V }, credentials: 'include' })).json()).d.GetContextWebInformation.FormDigestValue;
  const H = (extra) => Object.assign({ Accept: V, 'Content-Type': V, 'X-RequestDigest': digest }, extra || {});
  const call = async (path, method, body, extra) => {
    const r = await fetch(site + '/_api/' + path, { method: method || 'GET', headers: H(extra), credentials: 'include', body: body ? JSON.stringify(body) : undefined });
    const txt = await r.text();
    if (!r.ok) throw new Error((method || 'GET') + ' ' + path + ' -> ' + r.status + ' ' + txt.slice(0, 400));
    return txt ? JSON.parse(txt) : null;
  };
  const log = (...a) => console.log('%c[docpipe]', 'color:#0b6e4f;font-weight:bold', ...a);

  // ---- 1. the library must already exist ------------------------------------
  const libs = (await call("web/lists?$filter=BaseTemplate eq 101 and Hidden eq false&$select=Title,Id,RootFolder/ServerRelativeUrl&$expand=RootFolder")).d.results;
  const lib = libs.find(l => l.Title === LIBRARY);
  if (!lib) {
    console.error('[docpipe] Library "' + LIBRARY + '" not found on ' + site + '. Libraries here: ' + libs.map(l => '"' + l.Title + '"').join(', '));
    console.error('[docpipe] Set sharePointLibrary in env/<name>.json to one of those, rerun grant-graph.ps1, paste again.');
    return;
  }
  log('library "' + LIBRARY + '" found at ' + lib.RootFolder.ServerRelativeUrl);

  // ---- 2. the watched folder ------------------------------------------------
  const folderUrl = lib.RootFolder.ServerRelativeUrl + '/' + FOLDER;
  try {
    await call("web/GetFolderByServerRelativeUrl('" + folderUrl.replace(/'/g, "''") + "')?$select=Exists,UniqueId");
    log('folder "' + FOLDER + '" exists');
  } catch (e) {
    await call('web/folders', 'POST', { __metadata: { type: 'SP.Folder' }, ServerRelativeUrl: folderUrl });
    log('created folder ' + folderUrl);
  }

  // ---- 3. the results list --------------------------------------------------
  async function ensureList(displayName) {
    try {
      const l = await call("web/lists/getbytitle('" + displayName + "')?$select=Id,Title");
      log('list "' + displayName + '" exists'); return l.d;
    } catch (e) { /* create */ }
    const urlName = displayName.replace(/[^A-Za-z0-9]/g, '');
    const created = await call('web/lists', 'POST', { __metadata: { type: 'SP.List' }, Title: urlName, BaseTemplate: 100, Description: 'One row per document read by the pipeline. Lane says whether a person needs to look.', ContentTypesEnabled: false, AllowContentTypes: false });
    await call("web/lists(guid'" + created.d.Id + "')", 'POST', { __metadata: { type: 'SP.List' }, Title: displayName }, { 'IF-MATCH': '*', 'X-HTTP-Method': 'MERGE' });
    log('created list "' + displayName + '" (url name ' + urlName + ')');
    return created.d;
  }
  async function existingFields(listTitle) {
    const names = new Set();
    let url = "web/lists/getbytitle('" + listTitle + "')/fields?$select=InternalName&$top=500";
    while (url) {
      const r = await call(url);
      r.d.results.forEach(f => names.add(f.InternalName));
      const next = r.d.__next; url = next ? next.substring(next.indexOf('/_api/') + 6) : null;
    }
    return names;
  }
  // Create with DisplayName == internal name, so SharePoint cannot mangle the internal name.
  async function addField(listTitle, have, xml, name) {
    if (have.has(name)) { log('  field ' + name + ' exists'); return; }
    await call("web/lists/getbytitle('" + listTitle + "')/fields/createfieldasxml", 'POST', {
      parameters: { __metadata: { type: 'SP.XmlSchemaFieldCreationInformation' }, SchemaXml: xml, Options: 12 },
    });
    try { await call("web/lists/getbytitle('" + listTitle + "')/defaultview/viewfields/addviewfield('" + name + "')", 'POST'); } catch (e) { /* best effort */ }
    log('  + ' + name);
  }
  const text = (n) => '<Field Type="Text" Name="' + n + '" StaticName="' + n + '" DisplayName="' + n + '" MaxLength="255" />';
  const num = (n) => '<Field Type="Number" Name="' + n + '" StaticName="' + n + '" DisplayName="' + n + '" Decimals="3" />';
  const note = (n) => '<Field Type="Note" Name="' + n + '" StaticName="' + n + '" DisplayName="' + n + '" NumLines="6" RichText="FALSE" />';

  // Keep in step with graph.py RESULT_COLUMNS.
  const FIELDS = [
    ['DocType', text], ['Lane', text], ['Confidence', num], ['Summary', note], ['Fields', note], ['Evidence', note],
    ['SourceUrl', text], ['ItemId', text], ['Ticket', text], ['Model', text], ['PromptVersion', text],
  ];

  await ensureList(RESULTS_LIST);
  const have = await existingFields(RESULTS_LIST);
  for (const [name, xml] of FIELDS) await addField(RESULTS_LIST, have, xml(name), name);

  const present = await existingFields(RESULTS_LIST);
  const missing = FIELDS.map(f => f[0]).filter(n => !present.has(n));
  if (missing.length) { console.error('[docpipe] "' + RESULTS_LIST + '" is MISSING: ' + missing.join(', ') + '. Run again.'); return; }

  log('ALL DONE.  folder: ' + folderUrl + '   list: "' + RESULTS_LIST + '"');
  log('Next: the Graph Explorer step in env/<name>.grant-site.md, then ./publish.ps1');
})().catch(e => console.error('[docpipe] FAILED:', e));
