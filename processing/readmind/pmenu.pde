// 2012 - Frank Grimm (http://frankgrimm.net)
// popup menu for admistrative functions
// like closing the connection / application
import javax.swing.*;
import java.awt.event.*;

class PMenu {
  final JPopupMenu menu = new JPopupMenu();
  
  PMenu(PApplet parent) {

  JMenuItem item = null;
  
  item = new JMenuItem("Reconnect to device"); 
  item.addActionListener(new ActionListener() {
    void actionPerformed(ActionEvent e) {
      reconnectDevice();
    }
  });
  menu.add(item);
  
  item = new JMenuItem("Quit");
  item.addActionListener(new ActionListener() {
    void actionPerformed(ActionEvent e) {
      quitApplication();
    }
  });
  menu.add(item);
     
  // attach menu to the right click of the applet
  addMouseListener(new MouseAdapter() {        
    public void mouseReleased(MouseEvent evt) {
      if (evt.isPopupTrigger()) {
        menu.show(evt.getComponent(), evt.getX(), evt.getY());
      }
    }
  });
  }

}
