// 2012 - Frank Grimm (http://frankgrimm.net)

// Note: requires sans-serif font DejaVuSans

Mindwave mv = new Mindwave(this);
Menu mainMenu = new Menu();

void menuHandler(MenuItem triggeredItem) {
  if (null == triggeredItem) return;
  
  println("[INFO] Menu item triggered. Key: " + triggeredItem.getItemKey());
}

void setup_menu() {
  MenuItem actionsMenu = new MenuItem("actions", "Actions");
  actionsMenu.addItem(new MenuItem("do:poweron", "Power on"));
  actionsMenu.addItem(new MenuItem("do:poweroff", "Power off"));
  actionsMenu.addItem(new MenuItem("nav:back", "Back"));
  mainMenu.addItem(actionsMenu);
  
  MenuItem movementsMenu = new MenuItem("movement", "Movement");
  movementsMenu.addItem(new MenuItem("go:forward", "Forward"));
  movementsMenu.addItem(new MenuItem("go:backward", "Backward"));
  movementsMenu.addItem(new MenuItem("go:left", "Left"));
  movementsMenu.addItem(new MenuItem("go:right", "Right"));
  movementsMenu.addItem(new MenuItem("go:stop", "Stop"));
  movementsMenu.addItem(new MenuItem("nav:back", "Back"));
  mainMenu.addItem(movementsMenu);
  
  MenuItem keysMenu = new MenuItem("keys", "Keys");
  keysMenu.setGridDisplay();
  for (char c = 'A'; c <= 'Z'; c++) {
    keysMenu.addItem(new MenuItem("key:" + c, "" + c));
  }
  keysMenu.addItem(new MenuItem("nav:back", "Back"));
  mainMenu.addItem(keysMenu);
  
  MenuItem numbersMenu = new MenuItem("numbers", "Numbers");
  for (char c = '0'; c <= '9'; c++) {
    numbersMenu.addItem(new MenuItem("num:" + c, "" + c));
  }
  numbersMenu.addItem(new MenuItem("nav:back", "Back"));
  mainMenu.addItem(numbersMenu);
  
  mainMenu.init();
  mainMenu.setDrawArea(new Rectangle(300, 20, 460, 560));
}

void mousePressed() {
  mainMenu.processMouseEvent();
}

void mouseMoved() {
  mainMenu.processMouseMove();
}
  
void setup() {  
  // initialize drawing area
  size(800, 600);
  background(0);
  smooth();

  // initialize context menu
  PMenu menu = new PMenu(this);
  
  // initialize main menu
  setup_menu();
  
  // enumerate serial devices and wait for incoming data
  // tries to do a handshake to figure out which serial port
  // is used for the target device
  String targetDevice = "COM21";// mv.findDevice();
  mv.setDevice(targetDevice);
  
  if (targetDevice == null) {
    println("[ERROR] No suitable device found");
  }
 
  // synchronously try to handshake with the device
  if (targetDevice == null || !mv.connect()) {
    println("[ERROR] Could not connect.");
    exit();
    return;
  } else {
    println("[INFO] Connected to " + targetDevice);
  }
  
  // increase buffer size for raw signal renderer
  // as this will receive many more values than the single band
  // renderers
  rawSignalDrawer.setBufferSize(10240);
  // attach raw signal renderer instance to the parser instance
  mv.attachRawSignalRenderer(rawSignalDrawer);
  
  // setup blink detection based on the raw signal
  BlinkDetect bd = new BlinkDetect(400, 150);
  mv.attachBlinkDetector(bd);
  
  // attach file output (if any)
  if (fileSink != null) mv.attachFileSink(fileSink);
  
  // captions and colors for rendering the data for individual bands  
  String[] bandCaptions = {"delta", "theta", "alpha(low)", "alpha(high)", "beta(low)", "beta(high)", "gamma(low)", "gamma(mid)"};
  color[] bandColors = {color(255, 0, 0), color(255, 0, 100), color(150, 0, 255), color(40, 0, 255), color(0, 150, 255), color(0, 255, 120), color(200, 255, 0), color(255, 120, 0)};

  for(int bandIdx = 0; bandIdx < 8; bandIdx++) {
    // initialize renderer instance for the current band
    bandDrawers[bandIdx] = new ValueBoxDrawer(bandColors[bandIdx], new Rectangle(10, 80 + 53*bandIdx, 200, 50), bandCaptions[bandIdx]);
    // attach band renderer to the datasource
    mv.attachBandRenderer(bandIdx, bandDrawers[bandIdx]);
  }
  
}

// csv export
CsvFiles fileSink = new CsvFiles("../mv-data/"); // makes sense on my box, make sure to include trailing slash

// renderer instances
ValueBoxDrawer rawSignalDrawer = new ValueBoxDrawer(color(255), new Rectangle(10, 10, 200, 60), "RAW");
ValueBoxDrawer[] bandDrawers = new ValueBoxDrawer[8];

void draw() {
  // clear background and reset stroke
  background(0);
  stroke(255);
  
  // render raw signal plot
  rawSignalDrawer.draw();
  
  // render individual bands
  for (int bandIdx = 0; bandIdx < 8; bandIdx++) {
    if (bandDrawers[bandIdx] != null) bandDrawers[bandIdx].draw();
  }
  
  // render signal quality
  draw_mindwave_signal(mv, 220, 10, 50, 50);
  
  // draw menu
  mainMenu.draw();
  
  delay(50);
}

void performMenuAction(MenuItem item) {
  println("[INFO] Menu action: " + item);
}

boolean hasBlinked = false;

void blinkHandler(long duration) {
  println("[INFO] Blink event (" + duration + ") received.");
  switch(mainMenu.getTimer().getDuration()) {
    case 700:
    // ignore rapid duplicates
    mainMenu.getTimer().setDuration(500);
    mainMenu.getTimer().start();
    hasBlinked = false;
    break;
    case 500:
    // keep focus on item for 3s + .5s after first blink
    mainMenu.getTimer().setDuration(3000);
    mainMenu.getTimer().start();
    hasBlinked = false;
    case 3000:
    // received blink within the 3s window
    hasBlinked = true;
    break;
    default:
    mainMenu.getTimer().setDuration(700);
    mainMenu.getTimer().start();
  }
}

/* actions triggered by the context menu */
void quitApplication() {
  println("[USER] Quit");
  // disconnect from device
  mv.disconnect();
  // disconnect file output if necessary
  if (fileSink != null) {
    fileSink.close();
  }
  
  exit();
}

void reconnectDevice() {
  println("[USER] Reconnect");
  // disconnect from device
  mv.disconnect();
  println("[USER] Waiting 1 second");
  try {
    Thread.sleep(1000);
  } catch (InterruptedException ie) { /* ignore */ }
  println("[USER] Trying to reconnect");

  if (!mv.connect()) {
    println("[ERROR] Could not connect.");
    return;
  }
  println("[USER] Done reconnecting");
}

// helper class to define rendering areas for the value buffers
class Rectangle {
  public int x;
  public int y;
  public int w;
  public int h;
  
  Rectangle (int x, int y, int w, int h) {this.x = x; this.y = y; this.w = w; this.h = h; };
  Rectangle (Rectangle original) {this(original.x, original.y, original.w, original.h);};
  
  public boolean containsPoint(int x, int y) {
    return x >= this.x && y >= this.y && x <= this.x+this.w && y <= this.y+this.h;
  }
}

// buffers and renders value plots, including a caption
class ValueBoxDrawer {
  // font used to render the caption
  public PFont font = null; 
  // value buffer, may be increased with setBufferSize
  private int[] rawBuffer = new int[255]; 
  // internal offset for the current drawing iteration
  // this avoids shifting the whole buffer each time the data is drawn
  private int rawBufferDrawStart = 0; 
  // drawing area
  private Rectangle dim = null;
  // foreground color
  private color strokeColor = color(255);
  // caption text
  private String caption = "";
  
  // change the size of the display buffer. defaults to 255 values
  public void setBufferSize(int bufferSize) {
    this.rawBuffer = new int[bufferSize];
  }
  
  // defines a new renderer instance with the given color and caption in
  // the specified area
  ValueBoxDrawer(color strokeColor, Rectangle dim, String caption) {
    // initialize font only once per renderer instance as this operation is expensive
    this.font = createFont("DejaVuSans", 12);
    assert(this.font != null);
    
    this.strokeColor = strokeColor;
    this.dim = dim;
    this.caption = caption;
    
    for (int i = 0; i < rawBuffer.length; i++) rawBuffer[i] = 0;
  }
  
  // add a new value to the buffer
  public synchronized void newValue(int value) {
    rawBuffer[rawBufferDrawStart++] = value; 
    int bufferLen = rawBuffer.length;
    if (rawBufferDrawStart >= bufferLen) rawBufferDrawStart = 0;
  }
  
  // max(valuebuffer)-min(valuebuffer)
  private int spread = 0;

  private void updateSpread() {
    int val_min = rawBuffer[0];
    int val_max = val_min;
    for (int i = 0; i < rawBuffer.length; i++) {
      if (rawBuffer[i] < val_min) val_min = rawBuffer[i];
      if (rawBuffer[i] > val_max) val_max = rawBuffer[i];
    }
    spread = (val_max-val_min);
  }
  
  // render the current value buffer
  public void draw() {
    this.updateSpread();
    
    // reset fill and stroke
    noFill();
    strokeWeight(1);
    stroke(strokeColor);
    // draw border rectangle
    rect(dim.x, dim.y, dim.w, dim.h);
    
    // calculate distance on the x-axis between two datapoints
    int bufferLen = rawBuffer.length;
    float tileWidth = (float)dim.w/(float)bufferLen;
    
    // start at the vertical center and cache the last (x,y) values
    // for producing smooth, connected lines
    float lastY = dim.y + dim.h / 2.;
    float lastX = dim.x;
    
    // update caption
    if (font != null && caption != null && !"".equals(caption)) {
      textFont(font);
      textAlign(RIGHT, TOP);
      fill(255);
      text(caption, dim.x+dim.w-5, dim.y+1);
    }
    
    // no values to render
    if (spread == 0) 
      return;
     
    // plot the buffer content
    for (int i = 0; i < bufferLen; i++) {
       int cur_val = rawBuffer[(i + rawBufferDrawStart) % bufferLen];
  
       float newX = lastX + tileWidth;
       float newY = dim.y + (dim.h / 2.) + ((float)cur_val/(float)(spread) * (dim.h/2.));
       line(lastX, lastY, newX, newY);
       lastX = newX;
       lastY = newY;
    }
  }
}

// signal rendering with colored quality indicators
color[] signal_fill = {color(255, 0, 0), color(255, 113, 0), color(255, 230, 0), color(180, 255, 0), color(0, 255, 0)};
private void draw_mindwave_signal(Mindwave mv, int x, int y, int w, int h) {
  noFill();
  stroke(255);
  strokeWeight(1);
  
  // calculate width and height of the individual segments
  float offsetX = w/20.;
  float tileWidth = ((float)w - offsetX*4)/5.;
  float tileHeight = (float)h / 5.;
  
  // normalize and invert signal strength value
  float sigStrength = 5. - (mv.getSignalStrength()/100.)*5.;

  for (int sIdx = 0; sIdx < 5; sIdx++) {
    float offsetY = ((sIdx+1)*tileHeight);
    
    if (sIdx <= sigStrength) {
      // when the current signal strenght is greater or equal to the current level (0-4), the bar segment will be filled
      fill(signal_fill[sIdx]);
    } else {
      // inactive / unreached signal levels will be shown as a simple rectangle
      noFill();
    }
     
    // draw current segment   
    rect(x + (tileWidth+offsetX) * sIdx, y + h - offsetY, tileWidth, offsetY);
  }
}

