// 2012 - Frank Grimm (http://frankgrimm.net)
import java.util.*;

class Menu {
  private List<MenuItem> items = new ArrayList<MenuItem>();
  private Rectangle drawArea = new Rectangle(50, 50, 100, 100);
  private PFont font = null;
  private PFont fontTitle = null;
  private MenuItem currentItem = null;
  
  private MenuTimer timer = new MenuTimer(700);
  
  public MenuTimer getTimer() {
    return timer;
  }
  
  public Rectangle getDrawArea() {
    return drawArea;
  }
  
  public void addItem(MenuItem item) {
    item.setParent(null);
    item.setContainer(this);
    this.items.add(item);
  }
  
  public List<MenuItem> getRootItems() {
    return items;
  }
  
  public void setDrawArea(Rectangle area) {
    this.drawArea = area;
  }

  public void init() {
    this.font = createFont("DejaVuSans", 18);
    this.fontTitle = createFont("DejaVuSans", 12);
  }
  
  private List<MenuItem> getCurrentItems() {
    boolean isAtRoot = true;
    
    List<MenuItem> currentItems = new ArrayList<MenuItem>();
    if (this.currentItem != null && this.currentItem.hasItems()) {
      currentItems.addAll(this.currentItem.getItems());
      isAtRoot = false;
    }
    if (isAtRoot) {
      currentItems.addAll(this.getRootItems());
    }
    
    return currentItems;
  }
  
  public void activateCurrent() {
    for (MenuItem cmi: this.getCurrentItems()) {
      if (cmi.isHighlighted()) {
        itemActivated(cmi);
        return;
      }
    }
    return;
  }

  public void draw() {
    // retrieve items to show on the current level

    List<MenuItem> currentItems = this.getCurrentItems();
    
    if (this.timer.elapsed()) {
      if (hasBlinked && this.timer.getDuration() == 3000) {
        // blink within 3s window -> activate
        hasBlinked = false;
        this.timer.setDuration(700);
        this.timer.start();
        activateCurrent();
        return;
      }
      
      boolean foundHighlight = false;
      
      // move highlight
      for (int idx = 0; idx < currentItems.size(); idx++) {
        MenuItem cmi = currentItems.get(idx);
        if (cmi.isHighlighted()) {
          foundHighlight = true;
          resetHighlights();
          if (idx < currentItems.size()-1) {
            currentItems.get(idx+1).setHighlight();
          } else {
            currentItems.get(0).setHighlight();
          }
          break;
          
        }
      }
      if (!foundHighlight && currentItems.size() > 0) currentItems.get(0).setHighlight();
      this.timer.start(); // restart timer
    }
  
    // draw border    
    stroke(255);
    noFill();
    rect(drawArea.x, drawArea.y, drawArea.w, drawArea.h);
    
    if (currentItems.size() == 0) return;
    
    // draw title for current submenu
    String menuTitle = "/";
    boolean displayAsList = true;
    if (currentItem != null && currentItem.getTitle() != null) {
      menuTitle = currentItem.getTitle();
      //displayAsList = !currentItem.isDisplayAsGrid();
    }
    
    // calculate item dimensions
    int itemHeight = 0;
    int rowCount = -1;
    if (displayAsList) {
      itemHeight = (int)Math.floor((double)drawArea.h/(double)currentItems.size());
    } else {
      rowCount = 
      itemHeight = (int)Math.floor((double)drawArea.h/(double)rowCount);
    }
    if (itemHeight == 0) return;
    
    textFont(fontTitle);
    textAlign(LEFT, BOTTOM);
    fill(255);
    text(menuTitle, drawArea.x, drawArea.y);
    
    for (int i = 0; i < currentItems.size(); i++) {
      Rectangle drawItemAt = new Rectangle(drawArea);
      if (displayAsList) {
        // list display
        drawItemAt.y += i*itemHeight;
        drawItemAt.h = itemHeight;
      } else {
        // grid display
        // TODO
      }
      
      MenuItem drawCurrent = currentItems.get(i);
      if (drawCurrent == null) continue;
      drawCurrent.setLastDrawnAt(drawItemAt);

      noFill();
      
      if (drawCurrent.isHighlighted()) {
        strokeWeight(10);
        if (!hasBlinked) {
          stroke(color(0, 170, 255));
        } else {
          stroke(color(255, 0, 0));
        }
      } else {
        strokeWeight(1);
      }
      rect(drawItemAt.x, drawItemAt.y, drawItemAt.w, drawItemAt.h);
      
      strokeWeight(1);
      
      textFont(font);
      textAlign(CENTER, CENTER);
      if (drawCurrent.isHighlighted()) {
        fill(color(0, 170, 255));
      } else {
        fill(255);
      }
      text(drawCurrent.getTitle(), drawItemAt.x+drawItemAt.w/2., drawItemAt.y+itemHeight/2.);
      fill(255);
      
      stroke(255);
    }
  }
  
  private void navigateUp() {
    println("[DEBUG] Navigating up");
    this.resetHighlights();
    
    if (currentItem != null && currentItem.getParent() != null) {
      currentItem = currentItem.getParent();
    } else {
      currentItem = null;
    }
  }
  
  private void itemActivated(MenuItem item) {
    if (item == null) return;
    String activatedKey = item.getItemKey();
    
    if ("nav:back".equals(activatedKey)) {
      navigateUp();
      return;
    }
    
    if (item.hasItems()) {
      // descend into submenu
      println("[DEBUG] Descending into " + item);
      currentItem = item;
      return;
    }
    
    performMenuAction(item);
  }
  
  private MenuItem getItemAtPos(int x, int y) {
    if (drawArea.containsPoint(mouseX, mouseY)) {
      List<MenuItem> checkItems = this.getCurrentItems();
      for (MenuItem currentItem: checkItems) {
        if (currentItem.getLastDrawnAt() == null) continue;
        if (currentItem.getLastDrawnAt().containsPoint(mouseX, mouseY)) {
          return currentItem;
        }
      }
    }
    
    return null;
  }
  
  private void resetHighlights() {
    for(MenuItem item: this.getCurrentItems()) {
        item.resetHighlight();
    }
  }
  
  public void processMouseMove() {
    MenuItem currentItem = getItemAtPos(mouseX, mouseY);
    this.resetHighlights();  
    if (currentItem != null) {
      this.resetHighlights();
      currentItem.setHighlight();
    }
    
  }
  
  public void processMouseEvent() {
    MenuItem currentItem = getItemAtPos(mouseX, mouseY);
    if (currentItem == null) return;
    itemActivated(currentItem);
  }
}

class MenuTimer {
  private long startTime;
  private int duration = 0;
  
  public MenuTimer(int duration) {
    this.duration = duration;
    this.start();
  }
  
  public boolean elapsed() {
    return System.currentTimeMillis() - startTime > duration;
  }
  
  public void start() {
    startTime = System.currentTimeMillis();
  }
  
  public void setDuration(int duration) {
    this.duration = duration;
  }
  
  public int getDuration() {
    return this.duration;
  }
}

class MenuItem {
  private boolean displayAsGrid = false;
  private String title = "";
  private String itemKey = "";
  private MenuItem parent = null;
  private List<MenuItem> items = null;
  private Rectangle lastDrawnAt = null;
  private Menu container = null;
  private boolean highlight = false;
  
  public void resetHighlight() {
    highlight = false;
  }
  
  public void setHighlight() {
    highlight = true;
  }
  
  public boolean isHighlighted() {
    return highlight;
  }
  
  @Override
  public String toString() {
    return "[MenuItem:" + this.getItemKey() + " \"" + this.getTitle() + "\"]";
  }
  
  public void setGridDisplay() {
    this.displayAsGrid = true;
  }
  
  public boolean isDisplayAsGrid() {
    return displayAsGrid;
  }
  
  public MenuItem(String itemKey, String title) {
    this.title = title;
    this.itemKey = itemKey;
    this.container = container;
  }
  
  public Rectangle getLastDrawnAt() {
    return lastDrawnAt;
  }
  public void setLastDrawnAt(Rectangle area) {
    this.lastDrawnAt = area;
  }
  
  public void setContainer(Menu container) {
    this.container = container;
  }
  
  public String getTitle() {
    return title == null ? "[null]" : title;
  }
  
  public String getItemKey() {
    return itemKey == null ? "[null]" : itemKey;
  }
  
  public boolean hasItems() {
    return items != null && items.size() > 0;
  }
  public List<MenuItem> getItems() {
    return items;
  }
  
  public boolean isRoot() {
    return parent == null;
  }
  
  public MenuItem getParent() {
    return parent;
  }
  public void setParent(MenuItem parent) {
    this.parent = parent;
  }
  
  public void addItem(MenuItem child) {
    if (items == null) items = new ArrayList<MenuItem>();
    child.setParent(this);
    items.add(child);
  }
}

