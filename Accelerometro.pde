import java.awt.*;
import javax.swing.SwingUtilities;
import java.awt.event.InputEvent;
import java.awt.event.KeyEvent;

class Accelerometro {
  private boolean holdLeftClick;
  Sistema sistema = new Sistema(0, 0, -1000, 0, -15, 15);
  private boolean mouseUsed;
  private boolean leftClick;
  private boolean rightClick;
  private int numeroCampioniOffset = 100;
  private float[] offsetAcc = new float[3];
  private float distPiano;
  private int n; // Numero campione attuale. Serve per tenere conto a quale campione ci troviamo durante la calibrazione e per il campionamento
  private float xi, yi, zi;
  private float[] coordinateSchermo = new float[3];
  private float[] coordinateVersore = new float [3];
  private float[] mouse = new float[2];
  private float[] ypr = new float[3];
  private float[] acc = new float[3];
  private float[] vel = new float[3];
  private float[] pos = new float[3];
  private float[] accHold = new float[3];
  private float[] yprAccensione = new float[3];
  private String[] data = new String[7];
  private String[] dataName = { "y", "p", "r", "X", "Y", "Z", "l"};
  // Dichiaro un oggetto su cui scrivere nel caso io voglia effettuare un campionamento
  private PrintWriter output;
  // Il costruttore prende in ingresso solo la posizione iniziale del sensore e la distanza dal piano (valore che indica la sensibilità del mouse).
  public Accelerometro(float xi, float yi, float zi, float distPiano) {
    mouseUsed=false;
    this.distPiano = distPiano;
    this.xi = xi;
    this.yi = yi;
    this.zi = zi;
    for (int i = 0; i < 3; i++) {
      data[i]="0.0";
      ypr[i] = 0;
      yprAccensione[i] = 0;
      acc[i] = 0;
      accHold[i] = 0;
      offsetAcc[i] = 0;
      vel[i]=0;
      pos[i]=0;
      coordinateSchermo[i]=0;
      holdLeftClick=false;
    }
    n = 0;
  }
  // Costruttore nel caso vuoi campionare
  public Accelerometro(float xi, float yi, float zi, float distPiano, String nomeFile) {  
    this(xi, yi, zi, distPiano);   
    output = createWriter(nomeFile); // Aggiungo una stringa in ingresso per determinare il nome del file su cui scrivere
  }
  public void setN(int n) {
    this.n=n;
  }
  // Metodi privati
  private void updateVelocity() {
    for (int i = 0; i<3; i++) {
      vel[i]+=acc[i]*0.02;
    }
  }
  private void updatePosition() {
    for (int i = 0; i<3; i++) {
      pos[i]+=vel[i]*0.02;
    }
  }
  public void setMouseUsed(boolean used) {
    this.mouseUsed=used;
  }
  public boolean isMouseUsed() {
    return this.mouseUsed;
  }
  // Calcola offset delle accelerazioni
  private void calcolaOffset() {
    for (int i = 0; i < 3; i++) {
      offsetAcc[i] += acc[i];
      if (n == numeroCampioniOffset - 1) {
        // Questa parte di codice viene eseguita solo una volta ogni volta che accendiamo il mouse e non viene mai eseguita ciclicamente, dunque quel vallore di acc[i] è il valore di acc[i]
        // in un determinato istante
        offsetAcc[i] = (offsetAcc[i] / float(numeroCampioniOffset))-acc[i];
      }
    }
  }

  // Elimina i picchi indesiderati dai valori di accelerazione
  private void adjustAcc() {
    if (n < numeroCampioniOffset) {
      for (int i = 0; i < 3; i++) {  
        // Aggiorno acc[i] 
        accHold[i] = acc[i];
        acc[i] = float(data[i+3]);
        if (n > 0 && n != (numeroCampioniOffset - 1)) {
          if ((acc[i] > accHold[i] + 0.5 || acc[i] < accHold[i] - 0.5)) {
            acc[i] = accHold[i];
          }
        }
      }
      calcolaOffset();
    } else {
      for (int i = 0; i < 3; i++) {  
        // Aggiorno acc[i] 
        accHold[i] = acc[i];
        acc[i] = float(data[i+3])- offsetAcc[i] ;    
        if ((acc[i] > accHold[i]+0.5 || acc[i] < accHold[i] - 0.5) && n != numeroCampioniOffset && n != (numeroCampioniOffset +1)) {
          acc[i] = accHold[i];
        }
        if ((acc[i] < accHold[i] + 0.02 && acc[i] > accHold[i] - 0.02)) {
          acc[i] = accHold[i];
        }
      }
    }
  }

  // Ruota coordinate nello spazio
  private void rotate_(float x, float y, float z) {
    /*questa funzione mi serve anche a altro in altri programmi ma qua
     in pasto li do 0,1,0 chè è la direzine dell'asse y dell'accellerometro
     in quanto il modulo è unitario ovvero rappresenta un versore, so che la sua rotazione
     rappresentera a sua volta un versore
     dunque i dati in uscita saranno direttamente utilizzabili per parametrizzare una retta.
     */
    float x1, x2, x3, y1, y2, y3, z1, z2, z3;
    // Ruoto roll
    x1 = x;
    y1 = y * cos(ypr[2]) - z * sin(ypr[2]);
    z1 = y * sin(ypr[2]) + z * cos(ypr[2]);
    // Ruoto pitch
    x2 = x1 * cos(ypr[1]) + z1 * sin(ypr[1]);
    y2 = y1;
    z2 = z1 * cos(ypr[1]) - x1 * sin(ypr[1]);
    // Ruoto yaw
    x3 = x2 * cos(ypr[0]) - y2 * sin(ypr[0]);
    y3 = x2 * sin(ypr[0]) + y2 * cos(ypr[0]);
    z3 = z2;
    coordinateVersore[0] = x3;
    coordinateVersore[1] = y3;
    coordinateVersore[2] = z3;
  }
  // Interseca un piano a distanza distPiano, la distanza dal piano dipende dalla sensibilità richiesta nel costruttore
  private void intersecaPiano() {
    /*funzione calcola l'intersezione tra la direzione indicata e il piano chiaramente della coordinata y sullo schermo non c'è ne facciamo niente*/
    coordinateSchermo[0] = (distPiano - yi) * coordinateVersore[0] / coordinateVersore[1] + xi;
    coordinateSchermo[2] = (distPiano - yi) * coordinateVersore[2] / coordinateVersore[1] + zi;
    coordinateSchermo[1] = distPiano;
  }

  // Aggiorna le coordinate del mouse rispetto alla grandezza dello schermo
  private void updateCoordinateSchermo()
  {  
    intersecaPiano();
    mouse[0] = constrain(coordinateSchermo[0], -distPiano*sin(30.0*PI/180.0), distPiano*sin(30.0*PI/180.0));
    mouse[1] = constrain(coordinateSchermo[2], -distPiano*sin(15.0*PI/180.0), distPiano*sin(15.0*PI/180.0));
    mouse[0] = -map(mouse[0], 0, distPiano*sin(30.0*PI/180.0), 0, displayWidth/2) + displayWidth/2;
    mouse[1] =  map(mouse[1], 0, distPiano*sin(15.0*PI/180.0), 0, displayHeight/2) + displayHeight/2;
  }
  // Crea e scrive su file di testo tutti i dati sia in ingresso che elaborati ordinati in una matrica che ha per colonne in fila ypr + acc + coordinateVersore + mouse
  // Bisogna aggiungere una grafica che faccia intendere   quando si sta campionando
  private void createTxt(PrintWriter output, int ni, int nf) {
    if (n > ni+numeroCampioniOffset && n <= nf + numeroCampioniOffset) {
      // Scartando i 100 campioni necessari per la calibrazione se mi trovo nell'intervallo dei valori che voglio
      // acquisite scrivo sul file una riga con tutti i vettori contenti le informazioni necessarie
      for (int i = 0; i < 3; i++) {
        output.print(ypr[i] + "\t");
      }
      for (int i = 0; i < 3; i++) {
        output.print(acc[i] + "\t");
      }
      for (int i = 0; i < 3; i++) {
        output.print(vel[i] + "\t");
      }
      for (int i = 0; i < 3; i++) {
        output.print(pos[i] + "\t");
      }
      for (int i = 0; i < 3; i++) {
        output.print(coordinateVersore[i] + "\t");
      }
      for (int i = 0; i < 2; i++) {
        output.print(mouse[i] + "\t");
      }
      output.print("\n");
    }
  }

  private void closeTxt(PrintWriter output, int nf) {
    // se s ono arrivato all'ultimo elemento chiudo il file
    if (n == nf + numeroCampioniOffset) {
      output.flush();
      output.close();
    }
  }
  // Metodi pubblici
  //Da usare per campionare, indicare il campione iniziale e il campione finale
  public void campiona(int ni, int nf) {
    // Scrivo sul file da ni a nf contando i campioni a partire da dopo la calibrazione
    mpu6050.createTxt(output, ni, nf);
    // Chiudo il file e salvo se sono arrivato al'ultimo campione... attenzione se gli inverti non funziona più un cazzo.
    mpu6050.closeTxt(output, nf);
  }
  public float[] getAcc() {
    return acc;
  }
  // Da in uscita un vettore con gli angoli Yaw Pitch Roll in questo ordine
  public float[] getYpr() {
    return ypr;
  }
  // Da in uscita un vettore contenente le cordinate X Y del mouse sullo schermo
  public float[] getMouse() {
    if (inBuffer != null) {
      updateCoordinateSchermo();
    }
    return mouse;
  } 
  // Disegna sullo schermo il mouse di colore (r,g,b) grande dim
  public void drawMouse(int r, int g, int b, int dim) {
    mouse = mpu6050.getMouse();
    stroke(r, g, b);
    fill(r, g, b);
    ellipse(mouse[0], mouse[1], dim, dim);
    fill(0, 0, 0);
  }
  public void mouse() {
    mouse = getMouse();
    mouseUsed=true;    
    try { 
      Robot robot = new Robot();
      robot.mouseMove( round(mouse[0]), round(mouse[1]));
      if (leftClick&&!holdLeftClick) {
        robot.mousePress(InputEvent.BUTTON1_MASK);
      } else if (!leftClick&&holdLeftClick) {
        robot.mouseRelease(InputEvent.BUTTON1_MASK);
      }
      if (rightClick) {
      }
      holdLeftClick=leftClick;
    }




    catch (AWTException e) {
    }
  }




  // Da in uscita un vettore con le coordinate del versore che indica la direzione
  public float[] getDirection() {
    if (inBuffer != null) {
    }
    return coordinateVersore;
  }
  public float[] getVelocity() {
    return vel;
  }
  public float[] getPosition() {
    return pos;
  }
  private void setPosition(float x, float y, float z) {
    pos[0] = x;
    pos[1] = y;
    pos[2] = z;
  }
  private void setVelocity(float x, float y, float z) {
    vel[0] = x;
    vel[1] = y;
    vel[2] = z;
  }
  // Disegna il vettore che rappresenta l'orientamento del sensore in uno spazio tridimensionale
  public void drawDirection() {
    sistema.disegnaGriglia();
    for (int i = 0; i < 3; i++) {
      coordinateVersore[i] *= 100.0;
    }
    stroke(255, 255, 0);
    strokeWeight(5);

    line(xi, yi, zi, xi  + coordinateVersore[0], yi +  coordinateVersore[2], zi + coordinateVersore[1]);
  }
  // Aggiorna i dati ricavati dal sensore e quelli che ne vengono calcolati
  public void updateSensore(String inBuffer) {

    int l, pos;
    for (int i = 0; i <=6; i++) {
      l = inBuffer.length();
      pos = inBuffer.indexOf(dataName[i]); 
      data[i] = inBuffer.substring(0, pos-1);
      inBuffer = inBuffer.substring(pos+1, l);
      println(data[i]+ i);      
      if (i==6) {
        if (int(data[i])==1)
          leftClick=true;
        if (int(data[i])==0)
          leftClick=false;
        println(leftClick);
      }
    }
    if (n>0 && n< 1000) {
      for (int i = 0; i < 3; i++) {
        yprAccensione[i] += float(data[i]);
        ypr[i] = float(data[i]);
      }
    } else {
      for (int i = 0; i < 3; i++) {
        ypr[i] = float(data[i])-yprAccensione[i]/1000.0;
      }
    }
    adjustAcc();
    // L'update di velocità e posizione deve essere fatto in questo ordine dopo tutti i calcoli sulle accelerazioni
    updateVelocity();
    updatePosition();
    println(n);
    if (n < 1000) {
      println("calibrazione");
    }
    if (n == 1000) {
      println("pronto");
    }
    rotate_(0.0, 1.0, 0.0);
    n++;
  }
  // Metodi per gli eventi 
  // cosa succede se draggo
  public void mouseDragged() {
    sistema.mouseDragged();
  }
  // cosa succede se clicco
  public void mousePressed() {
    sistema.mousePressed();
  }// cosa succede quando mollo il click
  public void mouseReleased() {
  }
  public void keyPressed(char key, int keyCode) {
    sistema.keyPressed(key, keyCode);
  }
  public void keyReleased(char key, int keyCode) {
    sistema.keyReleased(key, keyCode);
  }
}