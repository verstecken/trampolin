import com.dhchoi.*;

CountdownTimer timer;



import processing.serial.*;
import processing.opengl.*;
import toxi.geom.*;
import toxi.processing.*;
import processing.sound.*;
import themidibus.*;

SinOsc sine;
MidiBus myBus; // The MidiBus

// NOTE: requires ToxicLibs to be installed in order to run properly.
// 1. Download from http://toxiclibs.org/downloads
// 2. Extract into [userdir]/Processing/libraries
//    (location may be different on Mac/Linux)
// 3. Run and bask in awesomeness

ToxiclibsSupport gfx;

Serial port;                         // The serial port
char[] teapotPacket = new char[14];  // InvenSense Teapot packet
int serialCount = 0;                 // current packet byte position
int synced = 0;
int interval = 0;

float[] q = new float[4];
Quaternion quat = new Quaternion(1, 0, 0, 0);

float[] gravity = new float[3];
float[] euler = new float[3];
float[] ypr = new float[3];

int prevWert;
int prevWert2;
int xPos = 1;
int cycle = 0;

int rate = 60;
PrintWriter log;

void setup() {

    timer = CountdownTimerService.getNewCountdownTimer(this).configure(1, 1000);
       
    log = createWriter("jumps.txt");   
    frameRate(rate);
    textSize(8);
    sine = new SinOsc(this);
    //sine.play();

    myBus = new MidiBus(this, -1, 1); // Create a new MidiBus with no input device and the default Java Sound Synthesizer as the output device.
  
  
    size(1200, 700);
    gfx = new ToxiclibsSupport(this);

  
    // display serial port list for debugging/clarity
    println(Serial.list()[3]);

    // get the first available port (use EITHER this OR the specific port code below)
    String portName = Serial.list()[3];
    
    // get a specific serial port (use EITHER this OR the first-available code above)
    //String portName = "COM4";
    
    // open the serial port
    port = new Serial(this, portName, 115200);
    
    // send single character to trigger DMP init/start
    // (expected by MPU6050_DMP6 example Arduino sketch)
    port.write('r');
    background(50);
    drawGrid(cycle);
}

int state = 0;
int note = 0;

IntList lastValues = new IntList(5);
int pittyCounter = 0;
float timeCounter = 0;

void draw() {
    if (millis() - interval > 1000) {
        // resend single character to trigger DMP init/start
        // in case the MPU is halted/reset while applet is running
        port.write('r');
        interval = millis();
    }
    
    float[] axis = quat.toAxisAngle();
    //rotate(axis[0], -axis[1], axis[3], axis[2]);
    
    int wert = round(q[1]*1000)*-1;
    int gwert = wert + height/2;
    
    int wert2 = round(q[2]*1000)*-1;
    int gwert2 = wert2 + height/2;
    //println(round(q[1]*1000));
    
    // GRAPH 
    

     
    if(lastValues.size() == 5) {
      if(lastValues.get(0) < lastValues.get(2) && lastValues.get(2) > lastValues.get(4) && pittyCounter <= 0 && wert > 10) {
        textSize(8);
        text(lastValues.get(2), xPos-1, lastValues.get(2)+20+height/2); // wirklich the highest?
        text(round(timeCounter/rate*100.0)/100.0+" s.", xPos-1, lastValues.get(2)+30+height/2);
        pittyCounter = 5;
        timeCounter = 0;
        
        // SEND MIDI
        myBus.sendNoteOn(0, 60, 127);
        
        log.println(lastValues.get(2));
      }
      lastValues.remove(0); 
    }
    lastValues.append(wert);
    pittyCounter--;
    timeCounter++;
    
    //println(lastValues); 
    

    
    stroke(200);
    line(xPos-1, prevWert, xPos, gwert);
    prevWert = gwert;
    
    stroke(0,200,0);
    line(xPos-1, prevWert2, xPos, gwert2);
    prevWert2 = gwert2;
    
    if(xPos >= width) {
      saveFrame("jumps_graph-######.png");
      xPos = 1;
      background(50);
      cycle++;
      drawGrid(cycle);
      println(cycle);
      
    } else { 
      xPos++;
    }

    int[] midiSequence = { 
      60, 62, 64, 65, 67, 69, 71, 72,0,0,0,0,0,0,0,0,0,0,0,0,0
    };

    float midiwert = map(wert, 17, 199, 0, 7);
    
    int channel = 0;
    int pitch = 64;
    int velocity = 127;


}

void keyPressed() {
  log.flush(); // Writes the remaining data to the file
  log.close(); // Finishes the file
  exit(); // Stops the program
}

void drawGrid(int cycle) {
   stroke(80);
   line(0, height/2, width, height/2);
   for(int i = 0; i < width; i += rate) {
     line(i, 0, i, height);
     if(i != 0) {
       text((cycle*(width/rate))+(i/rate), i+3, height-10);
     }
   }
   text("Seconds", 3, height-10);
}

void serialEvent(Serial port) {
    interval = millis();
    while (port.available() > 0) {
        int ch = port.read();

        if (synced == 0 && ch != '$') return;   // initial synchronization - also used to resync/realign if needed
        synced = 1;
        //print ((char)ch);

        if ((serialCount == 1 && ch != 2)
            || (serialCount == 12 && ch != '\r')
            || (serialCount == 13 && ch != '\n'))  {
            serialCount = 0;
            synced = 0;
            return;
        }

        if (serialCount > 0 || ch == '$') {
            teapotPacket[serialCount++] = (char)ch;
            if (serialCount == 14) {
                serialCount = 0; // restart packet byte position
                
                // get quaternion from data packet
                q[0] = ((teapotPacket[2] << 8) | teapotPacket[3]) / 16384.0f;
                q[1] = ((teapotPacket[4] << 8) | teapotPacket[5]) / 16384.0f;
                q[2] = ((teapotPacket[6] << 8) | teapotPacket[7]) / 16384.0f;
                q[3] = ((teapotPacket[8] << 8) | teapotPacket[9]) / 16384.0f;
                for (int i = 0; i < 4; i++) if (q[i] >= 2) q[i] = -4 + q[i];
                
                // set our toxilibs quaternion to new data
                quat.set(q[0], q[1], q[2], q[3]);
                //println(round(q[1]*1000));

                /*
                // below calculations unnecessary for orientation only using toxilibs
                
                // calculate gravity vector
                gravity[0] = 2 * (q[1]*q[3] - q[0]*q[2]);
                gravity[1] = 2 * (q[0]*q[1] + q[2]*q[3]);
                gravity[2] = q[0]*q[0] - q[1]*q[1] - q[2]*q[2] + q[3]*q[3];
    
                // calculate Euler angles
                euler[0] = atan2(2*q[1]*q[2] - 2*q[0]*q[3], 2*q[0]*q[0] + 2*q[1]*q[1] - 1);
                euler[1] = -asin(2*q[1]*q[3] + 2*q[0]*q[2]);
                euler[2] = atan2(2*q[2]*q[3] - 2*q[0]*q[1], 2*q[0]*q[0] + 2*q[3]*q[3] - 1);
    
                // calculate yaw/pitch/roll angles
                ypr[0] = atan2(2*q[1]*q[2] - 2*q[0]*q[3], 2*q[0]*q[0] + 2*q[1]*q[1] - 1);
                ypr[1] = atan(gravity[0] / sqrt(gravity[1]*gravity[1] + gravity[2]*gravity[2]));
                ypr[2] = atan(gravity[1] / sqrt(gravity[0]*gravity[0] + gravity[2]*gravity[2]));
    
                // output various components for debugging
                //println("q:\t" + round(q[0]*100.0f)/100.0f + "\t" + round(q[1]*100.0f)/100.0f + "\t" + round(q[2]*100.0f)/100.0f + "\t" + round(q[3]*100.0f)/100.0f);
                //println("euler:\t" + euler[0]*180.0f/PI + "\t" + euler[1]*180.0f/PI + "\t" + euler[2]*180.0f/PI);
                //println("ypr:\t" + ypr[0]*180.0f/PI + "\t" + ypr[1]*180.0f/PI + "\t" + ypr[2]*180.0f/PI);
                */
            }
        }
    }
}


    float midiToFreq(int note) {
      return (pow(2, ((note-69)/12.0)))*440;
    }
    
    