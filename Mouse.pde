
import processing.serial.*;

Accelerometro mpu6050;
Serial myPort;
String inBuffer;
float sensibilita;
Boolean isConnectedToSerial = false;
void setup() {
  //fullScreen(P3D); uncomment this line for use the method drawDirection
  sensibilita = 0.5;
  mpu6050 = new Accelerometro(0, 0, 0, sensibilita, "data.txt");
  isConnectedToSerial=false;
  if (Serial.list().length>0) {
    myPort = new Serial(this, Serial.list()[0], 115200);
    myPort.bufferUntil (108);
    isConnectedToSerial = true;
  }
}
void draw() {
  //background(255);  uncomment this line for use the method drawDirection
  if (Serial.list().length==0) {
    fill(0);
    text("collegare il mouse", width/2, height/2);
    return;
  } else if (!isConnectedToSerial) {
    myPort = new Serial(this, Serial.list()[0], 115200);
    mpu6050.setN(0);
    myPort.bufferUntil (108);
    isConnectedToSerial = true;
  }
  mpu6050.mouse();

  mpu6050.campiona(1, 1000);
}
void serialEvent( Serial myPort) {
  if (myPort.available() >0) {
    inBuffer = myPort.readString();

    mpu6050.updateSensore(inBuffer);
  }
}
void mouseDragged() {
  mpu6050.mouseDragged();
}
void mousePressed() {
  mpu6050.mousePressed();
}
void mouseReleased() {
}
public void keyPressed() {
  mpu6050.keyPressed(key, keyCode);
}
public void keyReleased() {
  mpu6050.keyReleased(key, keyCode);
}