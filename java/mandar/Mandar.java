package mandar;

import java.net.URLEncoder;

import lombok.SneakyThrows;

public class Mandar {

	@SneakyThrows (Exception.class)
	public static String urlf (String format, String... strings) {
		int next = 0;
		StringBuilder ret = new StringBuilder ();
		for (int i = 0; i < format.length (); i++) {
			char ch = format.charAt (i);
			if (ch != '%') {
				ret.append (ch);
				continue;
			}
			if (next == strings.length)
				throw new RuntimeException ("Not enough params in urlEnc");
			ret.append (URLEncoder.encode (strings [next++], "utf-8"));
		}
		if (next != strings.length)
			throw new RuntimeException ("Too many params in urlEnc");
		return ret.toString ();
	}

}
