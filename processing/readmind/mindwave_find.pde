// 2012 - Frank Grimm (http://frankgrimm.net)
// helper that tries to handshake and parse the beginning of each serial port
// until no more ports are available or a device send packets with a valid checksum
class MindwaveDeviceFinder {
  private String deviceID = null;
  private int baudRate = 9600;
  private PApplet parent = null;
  private final int readMax = 200; // maximum number of initial bytes to read
  
  MindwaveDeviceFinder(PApplet parent, String deviceID, int baudRate) {
      println("[MindwaveDeviceFinder] Trying \"" + deviceID + "\" at " + baudRate + " baud");
      this.deviceID = deviceID;
      this.baudRate = baudRate;
      this.parent = parent;
  }
  
  public boolean isMindwave() {
    boolean res = false;
   
    try {
      Serial port = new Serial(this.parent, deviceID, baudRate);
      int bytesRead = 0;
      int stage = 0;
      int pLength = -1;
      int pChecksum = 0;
      
      boolean dataAvailable = false;
      int timeout = 1000; // wait for data for 1 second (max)
      while (!dataAvailable) {
        dataAvailable = port.available() > 0;
        
        try {
          Thread.sleep(50);
        } catch (InterruptedException e) {}
          
        timeout -= 50;
        if (timeout <= 0) {
          println("Timeout reached");
          break;
        }
      }
      
      // simplified state machine that ends at the first packet with valid checksum
      // (or when readMax is exceeded)
      while (!res && port.available() > 0 && bytesRead <= this.readMax) {
        int inByte = port.read();
        bytesRead++;
        switch (stage) {
          case 0:
            if (inByte == 0xAA) {
              println("[PROTOCOL] Got initial SYNC (0xAA)");
              pChecksum = 0;
              pLength = -1;
              stage++; // wait for initial sync
            }
          break;
          case 1:
            if (inByte == 0xAA) 
              stage++; // second sync received
            else
              stage = 0; // reset
          break;
          case 2:
            if (inByte == 0xAA) {
              // ignore, stage is repeated
            } else if (inByte > 0xAA) {
              // too large, reset
              println("[PROTOCOL] P_LENGTH_TOO_LARGE");
              stage = 0;
            } else if (inByte < 0) {
              println("[PROTOCOL] P_LENGTH_NEGATIVE");
              stage = 0;
            } else {
              pLength = inByte;
              println("[PROTOCOL] pLength = " + pLength);
              stage++;
            }
          break;
          case 3:
            pLength--;
            pChecksum += inByte;
            if (pLength == 0) {
              stage++;
            }
          break;
          case 4:
            pChecksum &= 0xFF;
            pChecksum = ~pChecksum & 0xFF;
            if ((inByte & 0xFF) != (pChecksum & 0xFF)) {
              println("[PROTOCOL] Invalid checksum: " + pChecksum + " Checksum byte: " + inByte);
            } else {
              println("[PROTOCOL] Valid checksum");
              res = true;
              println("[MindwaveDeviceFinder] Device found");
            } 
          break;
          default: 
          stage = 0;
        }
      }
      
      // free the serial connection
      port.stop();
      port = null;
      println("[MindwaveDeviceFinder] " + bytesRead + " bytes read");
      if (bytesRead > this.readMax) {
        println("[MindwaveDeviceFinder] Aborting, no handshake found in " + this.readMax + " bytes");
      }
    } catch (Exception e) {
      println("[MindwaveDeviceFinder::isMindwave] " + e.getMessage());
    }
    if (res) {
      delay(150);
    }
    return res;
  }
  
  // will contain the last valid device id or null
  public String getDeviceID() {
    return this.deviceID;
  }
}
