// 2012 - Frank Grimm (http://frankgrimm.net)

// blink detection (simple moving average and some checks to 
// determine if a blink event might have occured in the current buffer)
class BlinkDetect extends ConcurrentLinkedQueue<Short> {
  private int bufferSize = 400;
  private int blinkBufferSize = 100;
  private long bufferSum = 0;
  private BitSet blinkBuffer = new BitSet(100);
  private int bitIndex = 0;
  private final double blinkThreshold = 2.5;
  
  BlinkDetect(int bufferSize, int blinkBufferSize) {
    this.bufferSize = bufferSize;
    this.blinkBufferSize = blinkBufferSize;
    this.blinkBuffer = new BitSet(blinkBufferSize);
  }
  
  @Override
  public boolean add(Short newValue) {
    newValue = (short)Math.abs(newValue);
    
    super.add(newValue);
    bufferSum = bufferSum + newValue;
    if (super.size() > this.bufferSize)
      bufferSum = bufferSum - super.remove();

    this.checkBlink(newValue);
    
    return true;
  }
  
  private int blinkCardinalityThreshold = 30;
  public int getBlinkCardinalityThreshold() {
    return blinkCardinalityThreshold;
  }
  public void setBlinkCardinalityThreshold(int value) {
    this.blinkCardinalityThreshold = value;
  }
  
  private long blinkStarted = -1;
  
  private void checkBlink(Short newValue) {
    if (++bitIndex > blinkBufferSize) {
      bitIndex = 0;
    }
    double currentValue = (double)newValue;
    double currentAvg = this.getValue();
    boolean setbit = false;
    if (currentValue > (blinkThreshold*currentAvg)) {
      setbit = true;
    }
    blinkBuffer.set(bitIndex, setbit);
    if (!this.isFilled()) return; // only process blinking when the buffer is filled
    
    int card = blinkBuffer.cardinality();
    if (card > blinkCardinalityThreshold) {
      // number of set bits > threshold, start blink if necessary
      if (blinkStarted == -1) {
        // start blink event
        blinkStarted = System.currentTimeMillis();
      }
    } else {
      if (blinkStarted > -1) {
        long currentMillis = System.currentTimeMillis();
        long blinkDuration = currentMillis - blinkStarted;
        blinkStarted = -1;
        // report blink
        blinkHandler(blinkDuration);
      }
    }
  }
  
  public double getValue() {
    if (super.size() == 0) return 0;
    return (double)bufferSum / (double)super.size();
  }
  
  public boolean isFilled() {
    return super.size() >= bufferSize;
  }
  
  public int getFillPercentage() {
    if (super.size() == 0) return 0;
    return (int)Math.floor((double)super.size() / (double)bufferSize * 100.);
  }
  
}
