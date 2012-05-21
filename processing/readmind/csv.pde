// 2012 - Frank Grimm (http://frankgrimm.net)
import java.text.SimpleDateFormat;

// buffered csv-file writer
class CsvFiles {
  // captions used for the header (first line in the output file)
  private final String[] columnIDs = {"time", "delta", "theta", "alpha_low", "alpha_high", "beta_low", "beta_high", "gamma_low", "gamma_mid"};  
  private final String delimiter = "\t";
  // value buffers
  private final int[][] valueBuffer = new int[9][];
  PrintWriter file_raw = null;
  String filename_raw = "";
  PrintWriter file_bands = null;
  String filename_bands = "";
  
  private boolean dataReceived = false;
  
  // initializes the data output. will create a timestamped csv-file in the target path
  CsvFiles(String targetPath) {
    String prefix = targetPath +  (new SimpleDateFormat("yyyyMMdd-HHmmss")).format(new Date()); 
    filename_raw = prefix + "-raw.csv";
    filename_bands = prefix + "-bands.csv";
    
    println("[CSV] Raw: " + filename_raw);
    println("[CSV] Bands: " + filename_bands);
    
    // initialize PrintWriter instances
    this.file_raw = createWriter(filename_raw);
    this.file_bands = createWriter(filename_bands);
  }
  
  private void printHeaders() {
    if (!this.dataReceived) {
      this.dataReceived = true;
      
      // print header (raw)
      this.file_raw.print("time");
      this.file_raw.print(delimiter);
      this.file_raw.println("raw");
      this.file_raw.flush();
      
      // print header (bands)
      for (int idx = 0; idx < 9; idx++) {
        this.file_bands.print(columnIDs[idx]);
        if (idx < 8) this.file_bands.print(delimiter);
      }
      this.file_bands.println();
      this.file_bands.flush();
    }
  }
  
  private void closePrintWriter(PrintWriter file) {
    if (file != null) {
      file.flush();
      file.close();
    }
  }
  
  public synchronized void close() {
    this.closePrintWriter(file_raw);
    println("[CSV] " + filename_raw + " closed");
    this.closePrintWriter(file_bands);
    println("[CSV] " + filename_bands + " closed");
  }
  
  // add a raw value to the buffer
  public synchronized void newRaw(short rawValue) {
    printHeaders();
    this.file_raw.print(millis());
    this.file_raw.print(delimiter);
    this.file_raw.println(Short.toString(rawValue));
  }
  
  // add values for the individual bands to the buffer
  public synchronized void newBandValues(int[] bandValues) {
    printHeaders();
    this.file_bands.print(millis());
    this.file_bands.print(delimiter); // skip first as this holds raw values only
    int cols = Math.min(bandValues.length, 8);
    for (int idx = 0; idx < cols; idx++) {
      this.file_bands.print(Integer.toString(bandValues[idx]));
      if (idx < cols-1) this.file_bands.print(delimiter);
    }
    this.file_bands.println();
  }
}
