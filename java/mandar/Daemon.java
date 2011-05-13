package mandar;

import java.io.BufferedReader;
import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.io.PrintStream;
import java.io.PrintWriter;
import java.io.StringWriter;
import java.net.ServerSocket;
import java.net.Socket;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.concurrent.Callable;

import lombok.Getter;
import lombok.Setter;
import lombok.SneakyThrows;

import org.json.simple.JSONValue;

public class Daemon {

	public static void main (String[] args) throws Exception {
		final File baseDir = new File (args [0]);
		ServerSocket serverSock = new ServerSocket (3776);
		while (true) {
			final Socket sock = serverSock.accept ();
			Thread thread = new Thread (new Runnable () {
				@Override
				public void run () {
					try {
						Worker worker = new Worker ();
						worker.setBaseDir (baseDir);
						worker.setIn (sock.getInputStream ());
						worker.setOut (sock.getOutputStream ());
						worker.go ();
						sock.close ();
					} catch (IOException e) {
					}
				}
			});
			thread.start ();
		}
	}

	static ByteArrayOutputStream baos = new ByteArrayOutputStream ();
	static {
		System.setOut (new PrintStream (baos));
		System.setErr (new PrintStream (baos));
	}

	static class Worker {

		@Getter @Setter File baseDir;
		@Getter @Setter InputStream in;
		@Getter @Setter OutputStream out;

		ConfigProcessor cp;
		boolean dataLoaded = false;

		BufferedReader br;
		PrintWriter pw;

		Map<String,Object> resultMap = new LinkedHashMap<String,Object> ();

		@SneakyThrows (Exception.class)
		public void send (String result) {
			Map<String,Object> newMap = new LinkedHashMap<String,Object> ();
			newMap.put ("result", result);
			newMap.putAll (resultMap);
			newMap.put ("output", baos.toString ());
			baos.reset ();
			String json = JSONValue.toJSONString (newMap) + "\n";
			byte[] bytes = json.getBytes ("utf-8");
			out.write (bytes);
			resultMap.clear ();
		}

		@SuppressWarnings ("unchecked")
		public void go () throws IOException {
			br = new BufferedReader (new InputStreamReader (in));

			// init config processor
			cp = new ConfigProcessor ();
			cp.init ();

			// send initial ok message
			send ("ok");

			String line;
			while ((line = br.readLine ()) != null) {
				Map<String,Object> commandMap = (Map<String,Object>) JSONValue.parse (line);
				String command = (String) commandMap.get ("command");

				if (command.equals ("exit")) {
					send ("ok");
					return;
				}

				if (command.equals ("shutdown")) {
					send ("ok");
					System.exit (0);
				}

				try {
					doCommand (command, commandMap);
				} catch (Exception e) {
					StringWriter stackTraceStringWriter = new StringWriter ();
					e.printStackTrace (new PrintWriter (stackTraceStringWriter));
					resultMap.put ("error", e.getClass ().getName () + ": " + e.getMessage ());
					resultMap.put ("stack", stackTraceStringWriter.toString ());
					send ("error");
					return;
				}
			}
		}

		public void doCommand (String command, Map<String,Object> commandMap) {

			if (command.equals ("ping")) {
				send ("ok");
			}

			if (command.equals ("reset")) {
				cp.reset ();
				send ("ok");
			}

			if (command.equals ("set-document")) {
				String name = (String) commandMap.get ("name");
				String doc = (String) commandMap.get ("document");
				cp.setDocument (name, doc);
				send ("ok");
			}

			if (command.equals ("compile-xslt")) {
				String path = (String) commandMap.get ("path");
				cp.compileXslt (path);
				send ("ok");
			}

			if (command.equals ("execute-xslt")) {
				String doc = cp.executeXslt ();
				resultMap.put ("document", doc);
				send ("ok");
			}
		}

	}
}
