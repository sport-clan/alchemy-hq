package mandar;

import static mandar.Mandar.urlf;

import org.json.simple.JSONObject;
import org.json.simple.JSONValue;

public class CouchDatabase {

	private CouchServer server;
	private String db;

	public CouchDatabase (CouchServer server, String db) {
		this.server = server;
		this.db = db;
	}

	public Object create (JSONObject doc) {
		return server.call ("POST", db, doc);
	}

	public Object get (String id) {
		String path = urlf ("%/%", db, id);
		return server.call ("GET", path);
	}

	public Object update (JSONObject doc) {
		String id = (String) doc.get ("_id");
		String path = urlf ("%/%", db, id);
		return server.call ("PUT", path, doc);
	}

	public Object delete (String id, String rev) {
		String path = urlf ("%/%?rev=%", db, id, rev);
		return server.call ("DELETE", path);
	}

	public Object view (String design, String view) {
		String path = urlf ("%/_design/%/_view/%", db, design, view);
		return server.call ("GET", path);
	}

	public Object viewKey (String design, String view, Object key) {
		String keyJson = JSONValue.toJSONString (key);
		String path = urlf ("%/_design/%/_view/%?key=%", db, design, view, keyJson);
		return server.call ("GET", path);
	}
}
