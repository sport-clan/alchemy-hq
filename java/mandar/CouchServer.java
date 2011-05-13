package mandar;

import static mandar.Mandar.urlf;
import lombok.SneakyThrows;

import org.apache.commons.io.IOUtils;
import org.apache.http.HttpEntity;
import org.apache.http.HttpEntityEnclosingRequest;
import org.apache.http.HttpHost;
import org.apache.http.HttpRequest;
import org.apache.http.HttpResponse;
import org.apache.http.client.HttpClient;
import org.apache.http.entity.StringEntity;
import org.apache.http.impl.client.DefaultHttpClient;
import org.apache.http.message.BasicHttpEntityEnclosingRequest;
import org.apache.http.message.BasicHttpRequest;
import org.json.simple.JSONObject;
import org.json.simple.JSONValue;

public class CouchServer {

	private String hostname;
	private int port;

	private HttpClient client;
	private HttpHost host;

	public CouchServer (String hostname, int port) {
		this.hostname = hostname;
		this.port = port;
	}

	public CouchServer () {
		this ("localhost", 5984);
	}

	public Object version () {
		String path = urlf ("");
		return call ("GET", path);
	}

	public Object all () {
		String path = urlf ("_all_dbs");
		return call ("GET", path);
	}

	public Object create (String db) {
		String path = urlf ("%", db);
		return call ("PUT", path);
	}

	public Object get (String db) {
		String path = urlf ("%", db);
		return call ("GET", path);
	}

	public Object tempView (String db, JSONObject code) {
		String path = urlf ("%/_temp_view", db);
		return call ("POST", path, code);
	}

	public Object call (String method, String path) {
		return call (method, path, null);
	}

	public Object call (String method, String path, Object request) {

		// encode request
		String requestString = request != null ? JSONValue.toJSONString (request) : null;

		// perform call
		String responseString = httpRequest (method, path, requestString);;

		// decode response
		Object response = JSONValue.parse (responseString);

		// throw errors
		if (response instanceof JSONObject
				&& ((JSONObject) response).get ("error") != null) {
			JSONObject responseObject = (JSONObject) response;
			String errorString = String.format ("%s: %s",
					responseObject.get ("error"),
					responseObject.get ("reason"));
			throw new RuntimeException (errorString);
		}

		// and return
		return response;
	}

	@SneakyThrows (Exception.class)
	public String httpRequest (String method, String path, String requestString) {

		// create client
		init ();

		// create request
		HttpRequest request;
		if (requestString != null) {
			HttpEntityEnclosingRequest entityRequest =
				new BasicHttpEntityEnclosingRequest (method, "/" + path);
			HttpEntity entity = new StringEntity (requestString);
			entityRequest.setEntity (entity);
			request = entityRequest;
		} else {
			request = new BasicHttpRequest (method, "/" + path);
		}

		// perform request
		HttpResponse response = client.execute (host, request);

		// read response
		HttpEntity responseEntity = response.getEntity ();
		String responseString = IOUtils.toString (responseEntity.getContent (), "utf-8");

		// and return
		return responseString;
	}

	public synchronized void init () {
		if (client == null) client = new DefaultHttpClient ();
		if (host == null) host = new HttpHost (hostname, port);
	}

	public CouchDatabase database (String name) {
		return new CouchDatabase (this, name);
	}

	public final static void main (String[] args) {
		CouchServer cs = new CouchServer ();

		JSONObject versionObject = (JSONObject) cs.version ();
		String versionString = (String) versionObject.get ("version");
		System.out.println ("Connected to CouchDB " + versionString);

		Object all = cs.all ();
		System.out.println ("All dbs: " + JSONValue.toJSONString (all));
	}
}
