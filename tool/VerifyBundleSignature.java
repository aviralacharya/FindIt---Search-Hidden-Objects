// JDK 17 source-file launcher: java VerifyBundleSignature.java bundle.aab SHA256
// Read-only verification. No keystores or signing passwords are read by this tool.
import java.io.InputStream;
import java.nio.file.Path;
import java.security.CodeSigner;
import java.security.MessageDigest;
import java.security.cert.X509Certificate;
import java.security.interfaces.RSAPublicKey;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.HexFormat;
import java.util.List;
import java.util.Locale;
import java.util.Set;
import java.util.jar.Attributes;
import java.util.jar.JarEntry;
import java.util.jar.JarFile;
import java.util.jar.Manifest;
import java.util.regex.Pattern;

class VerifyBundleSignature {
    private static final Pattern SIGNATURE_FILE = Pattern.compile(
        "META-INF/[^/]+\\.(SF|RSA|DSA|EC)", Pattern.CASE_INSENSITIVE);

    private static String quote(String value) {
        StringBuilder out = new StringBuilder("\"");
        for (char character : value.toCharArray()) {
            if (character == '\\' || character == '"') out.append('\\').append(character);
            else if (character < 32) out.append(String.format("\\u%04x", (int) character));
            else out.append(character);
        }
        return out.append('"').toString();
    }

    private static void require(boolean value, String message) {
        if (!value) throw new IllegalArgumentException(message);
    }

    public static void main(String[] args) {
        try {
            require(args.length == 2 && args[1].matches("[0-9a-fA-F]{64}"),
                "A bundle path and a pinned certificate SHA-256 are required.");
            String pin = args[1].toLowerCase();
            List<String> verified = new ArrayList<>();
            X509Certificate certificate = null;
            Set<String> names = new HashSet<>();
            List<String> signatureFiles = new ArrayList<>();
            int manifestEntries = 0;
            try (JarFile jar = new JarFile(Path.of(args[0]).toFile(), true)) {
                Manifest manifest = jar.getManifest();
                require(manifest != null, "Bundle has no signed JAR manifest.");
                var entries = jar.entries();
                byte[] buffer = new byte[65536];
                while (entries.hasMoreElements()) {
                    JarEntry entry = entries.nextElement();
                    require(names.add(entry.getName()), "Duplicate bundle entry.");
                    if (entry.isDirectory()) continue;
                    boolean metadata = entry.getName().equalsIgnoreCase("META-INF/MANIFEST.MF")
                        || SIGNATURE_FILE.matcher(entry.getName()).matches();
                    if (entry.getName().equalsIgnoreCase("META-INF/MANIFEST.MF")) {
                        require(entry.getName().equals("META-INF/MANIFEST.MF"),
                            "Bundle requires the canonical signed JAR manifest path.");
                        manifestEntries++;
                    }
                    if (SIGNATURE_FILE.matcher(entry.getName()).matches()) {
                        signatureFiles.add(entry.getName());
                    }
                    // JarVerifier validates the entry digest only after EOF.
                    try (InputStream input = jar.getInputStream(entry)) {
                        while (input.read(buffer) != -1) { }
                    }
                    if (metadata) continue;
                    Attributes attributes = manifest.getAttributes(entry.getName());
                    require(attributes != null && attributes.getValue("SHA-256-Digest") != null,
                        "Every bundle payload needs a signed SHA-256 manifest digest.");
                    CodeSigner[] signers = entry.getCodeSigners();
                    require(signers != null && signers.length == 1,
                        "Unsigned or multiply signed bundle payload.");
                    var certificates = signers[0].getSignerCertPath().getCertificates();
                    require(!certificates.isEmpty() && certificates.get(0) instanceof X509Certificate,
                        "Bundle payload has no X.509 signing certificate.");
                    X509Certificate leaf = (X509Certificate) certificates.get(0);
                    leaf.checkValidity();
                    String fingerprint = HexFormat.of().formatHex(
                        MessageDigest.getInstance("SHA-256").digest(leaf.getEncoded()));
                    require(fingerprint.equals(pin), "Bundle certificate does not match the pin.");
                    require(!leaf.getSubjectX500Principal().getName().toLowerCase(Locale.ROOT).contains("cn=android debug"),
                        "An Android Debug certificate cannot sign a production bundle.");
                    require(leaf.getPublicKey() instanceof RSAPublicKey
                        && ((RSAPublicKey) leaf.getPublicKey()).getModulus().bitLength() >= 2048,
                        "Bundle requires a strong RSA upload certificate.");
                    require(Set.of("SHA256WITHRSA", "SHA384WITHRSA", "SHA512WITHRSA")
                        .contains(leaf.getSigAlgName().toUpperCase(Locale.ROOT)),
                        "Bundle requires a strong RSA certificate signature algorithm.");
                    certificate = leaf;
                    verified.add(entry.getName());
                }
            }
            require(certificate != null && !verified.isEmpty(), "Bundle has no signed payload.");
            require(manifestEntries == 1, "Bundle must have exactly one signed JAR manifest.");
            require(signatureFiles.size() == 2, "Bundle must have one complete JAR signature pair.");
            String sf = signatureFiles.stream().filter(name -> name.toUpperCase(Locale.ROOT).endsWith(".SF"))
                .findFirst().orElse("");
            String rsa = signatureFiles.stream().filter(name -> name.toUpperCase(Locale.ROOT).endsWith(".RSA"))
                .findFirst().orElse("");
            require(!sf.isEmpty() && !rsa.isEmpty()
                && sf.substring(0, sf.length() - 3).equalsIgnoreCase(rsa.substring(0, rsa.length() - 4)),
                "Bundle must have one matching RSA/SF signature pair.");
            verified.sort(String::compareTo);
            List<String> quoted = verified.stream().map(VerifyBundleSignature::quote).toList();
            System.out.println("{\"status\":\"passed\",\"certificateSha256\":" + quote(pin)
                + ",\"certificateSubject\":" + quote(certificate.getSubjectX500Principal().getName())
                + ",\"certificateSignatureAlgorithm\":" + quote(certificate.getSigAlgName())
                + ",\"keyAlgorithm\":\"RSA\",\"keySize\":"
                + ((RSAPublicKey) certificate.getPublicKey()).getModulus().bitLength()
                + ",\"validFrom\":" + quote(certificate.getNotBefore().toInstant().toString())
                + ",\"validUntil\":" + quote(certificate.getNotAfter().toInstant().toString())
                + ",\"signedPayloadEntries\":" + verified.size()
                + ",\"signedEntries\":[" + String.join(",", quoted) + "]}");
        } catch (SecurityException error) {
            System.out.println("{\"status\":\"failed\",\"error\":\"Bundle cryptographic signature verification failed.\"}");
            System.exit(1);
        } catch (Exception error) {
            String message = error instanceof IllegalArgumentException ? error.getMessage()
                : "Bundle signature or certificate verification could not complete.";
            System.out.println("{\"status\":\"failed\",\"error\":" + quote(message) + "}");
            System.exit(1);
        }
    }
}
