// 2012 - Frank Grimm (http://frankgrimm.net)
import processing.serial.*;
import java.util.concurrent.*;
import java.util.*;

// parser and dataprocessing for the device
class Mindwave {
  private int baudRate = 9600; // fixed baud rate as specified by the vendor
  private String targetDevice = null; // will hold the device id
  private PApplet parent = null; // parent PApplet to receive serial events (required by the processing serial I/O API)
  private Serial port = null; // Serial object
  
  public Mindwave(PApplet parent, String attachToDevice, int baudRate) {
    this(parent);
    this.baudRate = baudRate;
    this.targetDevice = attachToDevice;
  }
  
  public Mindwave(PApplet parent) {
    this.parent = parent;
  }
  
  /*
   * Search for a mindwave device and return the appropriate device id.
   */
  public String findDevice() {
    String allDevices[] = Serial.list();
    for (String currentDevice: allDevices) {
      MindwaveDeviceFinder mdf = new MindwaveDeviceFinder(this.parent, currentDevice, this.baudRate);

      if (mdf.isMindwave()) {
        this.targetDevice = currentDevice;
        return currentDevice;
      }      
    }
    
    return null;
  }
  
  // set target device id
  public void setDevice(String targetDevice) {
    this.targetDevice = targetDevice;
  }
  
  // connect to the target device by initializing the serial I/O port
  // will stop previously opened serial connections before creating
  // new ones (so this can be used to reset without restarting later on)
  public boolean connect() {
    if (this.targetDevice == null) {
      println("No device set");
      return false;
    }
    
    if (this.port != null) {
      try {
        println("[Mindwave::connect] Stopping previous connection");
        this.port.stop();
      } catch (Exception e) {
        println("[Mindwave::connect] " + e.getMessage());
      }
      this.port = null;
    }
    
    this.port = new Serial(this.parent, this.targetDevice, this.baudRate);
    if (this.port != null) {
      // initialize parser and start receiving data from the device in another thread
      mv.startReader();
      return true;
    }
    
    return false;
  }
  
  // disconnect from the serial port and indicate that the parser thread
  // should stop processing soon
  public boolean disconnect() {
    println("[Mindwave] Disconnecting");
    boolean success = true;
    try {
      // stop reader thread
      if (null != this.readerThread) this.readerThread.setAbort();
    } catch (Exception e) {
      success = false;
    }
    
    try {
      // close serial connection
      this.port.stop();
      this.port = null;
    } catch (Exception e) {
      println("[ERROR] " + e.getMessage());
      success = false;
    }
    
    return success;
  }
  
  // parser thread instance
  private MindwaveReader readerThread = null;
  
  // initialize and create a parser thread
  // requires a valid and connected device
  // as this starts processing right away
  public synchronized void startReader() {
    if (readerThread == null) {
      readerThread = new MindwaveReader();      
    } else {
      println("[DEBUG] startReader called on instance that was previously activated");
    }
    
    if (!readerThread.isActive()) {
      readerThread.start();
    }
  }
  
  /* buffers and external access methods */
  private int signalStrength = 100;
  private int attentionLevel = 0;
  private int meditationLevel = 0;
  
  public int getAttentionLevel() {
    return attentionLevel;
  }
  
  public int getMeditationLevel() {
    return meditationLevel;
  }
  
  public int getSignalStrength() {
    return signalStrength;
  }
    
  short latestRAW = -1;
  public short getLatestRawValue() {
    return latestRAW;
  }
  int latestBandValues[] = new int[8];
  public int[] getBandValues() {
    return latestBandValues;
  }
  /* /value holders */
  
  // renderers / sinks for newly received values from the parser thread
  private ValueBoxDrawer rawSignalDrawer = null;
  private ValueBoxDrawer[] bandSignalDrawer = new ValueBoxDrawer[8];
  public void attachRawSignalRenderer(ValueBoxDrawer obj) {
    this.rawSignalDrawer = obj;
  }
  public void attachBandRenderer(int bandIndex, ValueBoxDrawer obj) {
    this.bandSignalDrawer[bandIndex] = obj;
  }
  
  // file output
  private CsvFiles fileOutput = null;
  public void attachFileSink(CsvFiles fileOutput) {
    this.fileOutput = fileOutput;
  }

  private BlinkDetect mavg = null;
  public void attachBlinkDetector(BlinkDetect bd) {
    this.mavg = bd;
  }
  
  // called when new raw values are read by the parser
  // will update the member variable and attached renderer (if any)
  void setRaw(short value) {
    latestRAW = value;
    
    // update moving average and check for blink events
    if (mavg != null) {
      mavg.add(value);
      if (!mavg.isFilled()) {
        println("Buffer fill " + mavg.getFillPercentage() + "%");
      }
    }
    
    if (this.rawSignalDrawer != null) {
      synchronized(this.rawSignalDrawer) {
        this.rawSignalDrawer.newValue(value);
      }
    }
    if (this.fileOutput != null) {
      synchronized(this.fileOutput) {
        this.fileOutput.newRaw(value);
      }
    }
  }

  // called when new values for all bands are read by the parser
  // will update the member variable and attached renderer (if any)  
  synchronized void setBandValues(int[] bandValues) {
    latestBandValues = bandValues;
    for (int bandIdx = 0; bandIdx < bandValues.length; bandIdx++) {
      if (bandIdx >= 8) break; // invalid band index, should not happen
      if (this.bandSignalDrawer[bandIdx] != null) {
        this.bandSignalDrawer[bandIdx].newValue(bandValues[bandIdx]);
      }
      
      if (this.fileOutput != null) {
        synchronized(this.fileOutput) {
          this.fileOutput.newBandValues(bandValues);
        }
      }
    }
  }

  // some quality assurance by keeping track of invalid and successfully parsed packets  
  long unknownCodeCount = 0;
  int packetsOkay = 0;
  // when this value gets to high in relation to packetsOkay, it might be a good idea to reinitialize the parser
  // and/or the serial connection to the device
  public long getUnknownCodeCount() {
    return unknownCodeCount; 
  }
  
  // parser thread
  class MindwaveReader extends Thread {
    // indicates whether the parser is active
    boolean active = false;
    // this may be used to indicate that the creator of the thread
    // wants the thread to abort gracefully
    boolean abortReader = false;
    
    public boolean isActive() {
      return active;
    }
    
    public void setAbort() {
      this.abortReader = true;
    }
    
    // called when starting the thread
    void start() {
      this.abortReader = false;
      this.active = true;
      println("[MindwaveReader] Starting");
      super.start();
    }
    
    // run method, waits for data and parses all incoming packets
    void run() {
      while (!abortReader) {        
        waitForData();
        if (abortReader) return;
        parseData();
        if (abortReader) return;
      }
    }
    
    // interrupt parser execution
    void quit() {
      this.active = false;
      this.setAbort();
      interrupt();
    }
    
    // wait (for max. 10 seconds) until new data becomes available on the serial
    // connection
    private void waitForData() {
      boolean dataAvailable = false;
      int timeout = 10000; // wait for data for 10 second (max)
      while (!dataAvailable) {
        dataAvailable = port.available() > 0;
        
        try {
          Thread.sleep(50);
        } catch (InterruptedException e) {}
          
        timeout -= 50;
        if (timeout <= 0) {
          println("[MindwaveReader] Timeout reached");
          break;
        }
        
        if (abortReader) return;
      }
    }
    
    // packet parser
    int stage = 0; // parser stage
    int pLength = -1; // payload length
    int pChecksum = 0; // packet checksum
    final int DATABUF_LEN = 170; // payload buffer length
    byte[] DATABUF = new byte[DATABUF_LEN]; // payload buffer
    int bufPosition = 0; // current payload end position
    int bufStart = 0; // current parsing position
    
    // handle a single data row in the current buffer
    private void handleDataRow(int exCode, byte code, int plen, int bufferStart) {
      if (exCode != 0) {
        println("[PROTOCOL] UNKNOWN(ExCode) ExCode " + exCode + " Code " + code + " Len " + plen);
        bufferStart += plen; // skip len
        return;
      }

      packetsOkay++;      
      switch ((int)(code & 0xFF)) {
        case 0x02: // POOR_SIGNAL Quality 0-255, len=1
          signalStrength = (DATABUF[bufferStart++] & 0xFF);
          // println("Signal: " + signalStrength);
          break;
        case 0x04: // ATTENTION 0-100 
          // the device doesn't seem to send this apperently but meh..
          attentionLevel = (0xFF & DATABUF[bufferStart++]);
          break;
        case 0x05: // MEDITATION 0-100
          // the device doesn't seem to send this apperently but meh..
          meditationLevel = (0xFF & DATABUF[bufferStart++]);
          break;
        case 0x16: // Blink strength (0-255)
          println("Blink, strength: " + (0xFF & DATABUF[bufferStart++]));
          break;
        case 0x80: // raw wave value, big-endian - 16 bit - two's complement signed value
          byte high = DATABUF[bufferStart++];
          byte low = DATABUF[bufferStart++];
          short value = (short)(((high & 0xFF) << 8) | (low & 0xFF));
          setRaw(value); // cache and report raw data value
          // println("[PROTOCOL] RAW value: " + value);
          break;
        case 0x83: // ASIC_REG_POWER, eight big-endian 3-byte unsigned integers
          // order: delta, theta, low-alpha, high-alpha, low-beta, high-beta, low-gamma, mid-gamma
          int bandValues[] = new int[8];
          for (int bandIdx = 0; bandIdx < 8; bandIdx++) {
            int val = 0;
            for (int cByte = 0; cByte < 3; cByte++) {
              val |= (DATABUF[bufStart++] & 0xFF);
              if (cByte < 2) val <<= 8;
            }
            bandValues[bandIdx] = val;
//            println("[PROTOCOL] BAND" + bandIdx + ": " + val);
          }
          setBandValues(bandValues); // cache and report band values
          break;
        case 0x55:
        break;
        case 0xAA:
        break;
        case 0xD4: // seems to mean "no paired device" or similar
        break;
        default:
          println("[PROTOCOL] UNKNOWN: ExCode " + exCode + " Code " + (code & 0xFF) + " Len " + plen);
          unknownCodeCount++;
          packetsOkay--;
          bufferStart += plen; // skip len
      }
      
      if (packetsOkay > 200) { // somewhat arbitrary
        unknownCodeCount = 0; // reset unknown code count
      }
    }

    // when a packet with payload is received, this is used to buffer the data
    // before processing it
    private void parsePayload() {
      while (bufStart < bufPosition) {
        int exCodeCount = 0;
        
        while (bufStart < bufPosition && (DATABUF[bufStart] & 0xFF) == 0x55) {
          exCodeCount++;
          bufStart++;
        }
        
        byte code = DATABUF[bufStart++];
        
        int plen = 1;
        if ((code & 0x80) != 0) {
          plen = DATABUF[bufStart++] & 0xFF;
        }
        
        handleDataRow(exCodeCount, code, plen, bufStart);
        bufStart += plen;
      }
      bufStart = 0;
      bufPosition = 0;
    }
    
    // read data and walk it through a state machine
    // checksums and valid order are checked here
    private void parseData() {
     
      while (port.available() > 0) {
        if (abortReader) return;
        
        int inByte = port.read();

        switch (stage) {
          case 0:
            if (inByte == 0xAA) {
              // println("[PROTOCOL] Got initial SYNC (0xAA)");
              pChecksum = 0;
              pLength = -1;
              bufPosition = 0;
              bufStart = 0;
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
              // println("[PROTOCOL] pLength = " + pLength);
              stage++;
            }
          break;
          case 3:
            pLength--;
            pChecksum += inByte;
            if (bufPosition < DATABUF_LEN) {
              DATABUF[bufPosition++] = (byte)inByte;
            } else {
              println("[PROTOCOL] Buffer overflow");
              bufPosition = 0;
              stage = 0;
            }
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
              parsePayload();
            } 
            
            // full data received, start looking for SYNC again
            stage = 0;
          break;
          default: 
          stage = 0;
        }
      }
      
    }
  }
}

