import org.basex.api.client.LocalSession;
import org.basex.core.Context;
import org.basex.core.cmd.XQuery;
import org.basex.io.IO;
import org.basex.query.value.seq.StrSeq;

import java.io.IOException;
import java.nio.file.Paths;
import java.util.Arrays;

public class Greenfox {

    public static void main(String[] args) throws IOException {

        String baseDir = System.getProperty("basedir");
        if (baseDir == null) {
            throw new IllegalArgumentException("System property basedir must be set!");
        }

        Context context = new Context();

        IO queryFile = IO.get(Paths.get(baseDir, "bin/greenfox-cli.xq").toString());
        XQuery query = new XQuery(queryFile.string());
        query.bind("args", StrSeq.get(Arrays.stream(args).map(String::getBytes).toArray(byte[][]::new)));

        try (LocalSession ss = new LocalSession(context, System.out)) {
            ss.execute(query.baseURI(queryFile.path()));
        }

    }
}
