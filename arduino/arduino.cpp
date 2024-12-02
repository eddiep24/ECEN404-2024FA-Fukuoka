#include <WiFi.h>
#include <NTPClient.h>
#include <WiFiUdp.h>
#include <Firebase_ESP_Client.h>
#include "addons/TokenHelper.h"
#include "addons/RTDBHelper.h"

#define WIFI_SSID "Dalton's iPhone"
#define WIFI_PASSWORD "dalton123"
#define API_KEY "AIzaSyDJX17IPMPCVG0MXSG6uQ8ufObRaHBcJ2E"
#define DATABASE_URL "https://fukuoka-f4318-default-rtdb.firebaseio.com/"
#define DAC1_PIN 25
#define DAC2_PIN 26


#define VOLT_PIN 34
#define SLEEP_INTERVAL_SECONDS 30
#define DATA_INTERVAL 30000
#define ARRAY_SIZE 5
#define VARIANCE_THRESHOLD 0.05
#define READINGS_PER_SECOND 5

FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;

WiFiUDP ntpUDP;
NTPClient timeClient(ntpUDP, "pool.ntp.org");

static float lowestReading = __INT_MAX__; // Set highest to a low value
unsigned long sendDataPrevMillis = 0;
bool signupOK = false;
float voltData = 0.0;
float voltage = 0.0;
String realTime;
int tryDelay = 500;
int numberOfTries = 100;
float sensnum = 0.0;
float randsens = 0.0;
float ar[ARRAY_SIZE];
unsigned long lastReadTime = 0;

// RTC_DATA_ATTR bool deepSleepFlag = false;
// RTC_DATA_ATTR uint32_t rtcTimeSaved = 0;

float calculateVariance(float arr[], int n) {
    float sum = 0.0;
    for (int i = 0; i < n; i++) {
        sum += arr[i];
    }
    float mean = sum / n;

    float sqDiff = 0.0;
    for (int i = 0; i < n; i++) {
        float diff = arr[i] - mean;
        sqDiff += diff * diff;
    }
    return sqDiff / n;
}

void setup() {
  // put your setup code here, to run once:
  Serial.begin(115200);

  uint dac2Value = 8; // Scale 0.17V to DAC range
  dacWrite(DAC2_PIN, dac2Value);
  // Serial.print("Output voltage set to ~0.17V with DAC value: ");
  // Serial.println(dacValue);

  uint dac1Value = 255;
  dacWrite(DAC1_PIN, dac1Value);

  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  Serial.print("Connecting to WiFi");
  while(WiFi.status() != WL_CONNECTED && numberOfTries > 0) {
    Serial.print("."); delay(300); numberOfTries--;
  }
  if (WiFi.status() != WL_CONNECTED) {
      Serial.println("Failed to connect to WiFi!");
      WiFi.disconnect();
      return;
  }

  numberOfTries = 100;

  Serial.println();
  Serial.print("Connected with IP: ");
  Serial.println(WiFi.localIP());
  Serial.println();

  config.api_key = API_KEY;
  config.database_url = DATABASE_URL;
  if(Firebase.signUp(&config, &auth, "", "")) {
    Serial.println("Sign in Authenticated");
    signupOK = true;

  } else {
    Serial.printf("s%\n", config.signer.signupError.message.c_str());

}

  config.token_status_callback = tokenStatusCallback;
  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);

  timeClient.begin();
  timeClient.setTimeOffset(19 * 3600);

}




void loop() {
    unsigned long currentTime = millis();

    timeClient.update();
    realTime = timeClient.getFormattedTime();

    if (currentTime - lastReadTime >= 1000 || lastReadTime == 0) {

        
        bool stableReading = false;
        float lastVoltage = 0.0;
        
        for (int i = 0; i < READINGS_PER_SECOND; ++i) {
            voltage = (float)analogReadMilliVolts(VOLT_PIN)/1000.0;
            lastVoltage = voltage; // Save the last reading in case we don't get a stable one
            
            if (i >= READINGS_PER_SECOND - ARRAY_SIZE) {
                ar[i - (READINGS_PER_SECOND - ARRAY_SIZE)] = voltage;
                
                // Only check variance after we have enough readings
                if (i == READINGS_PER_SECOND - 1) {
                    float var = calculateVariance(ar, ARRAY_SIZE);
                    if (var < VARIANCE_THRESHOLD) {
                        stableReading = true;
                        sendFireBase(voltage);
                    } else {
                        // If reading not stable, send last voltage anyway
                        // sendFireBase(lastVoltage);
                        sendFireBase(voltage);
                    }
                }
            }
            
            delayMicroseconds(50000); // 50ms delay between readings
        }
        
        lastReadTime = currentTime;
    }
}

void sendFireBase(float reading) {
    if(Firebase.RTDB.setFloat(&fbdo, "SensorTest/voltage", reading)) {
        Serial.print("Voltage " + String(reading, 3) + "V saved to: " + fbdo.dataPath());
        Serial.println(" (" + fbdo.dataType() + ")");
    } else {
        Serial.println("Failed to save voltage: " + fbdo.errorReason());
    }

    if (Firebase.RTDB.setString(&fbdo, "SensorTest/real_time", realTime)) {
        Serial.println("Time " + realTime + " saved to: " + fbdo.dataPath());
    } else {
        Serial.println("Failed to save time: " + fbdo.errorReason());
    }
}

// void sendToFireBase() {
//   if (Firebase.ready() && signupOK && (millis() - sendDataPrevMillis > DATA_INTERVAL || sendDataPrevMillis == 0)) {
    

//     if (Firebase.RTDB.get(&fbdo, "SensorTest/sensornum")) {
//     // Check if the data returned is of the expected type
//       if (fbdo.dataType() == "int") {
//         sensnum = fbdo.intData();  // Retrieve the integer data
//         Serial.println(sensnum);


//       } else {
//         // If the data is not an integer
//         Serial.println("Error: Data is not of type int");
//       }
//     } else {
//       // If the read fails
//       Serial.println("Failed to read from Firebase: " + fbdo.errorReason());
//     }


    
//     sendDataPrevMillis = millis();

    

//     if(Firebase.RTDB.setInt(&fbdo, "SensorTest/volt_data", voltData)) {
//       Serial.println(); //Serial.print(voltData);
//       Serial.print("voltData successfully saved to: " + fbdo.dataPath());
//       Serial.println(" (" + fbdo.dataType() + ")");

//     } else {
//       Serial.println("failed: " + fbdo.errorReason());
//     }

//     if(Firebase.RTDB.setInt(&fbdo, "SensorTest/voltage", voltage)) {
//       Serial.println(); //Serial.print(voltage);
//       Serial.print("voltage successfully saved to: " + fbdo.dataPath());
//       Serial.println(" (" + fbdo.dataType() + ")");

//     } else {
//       Serial.println("failed: " + fbdo.errorReason());
//     }

//     if (Firebase.RTDB.setString(&fbdo, "SensorTest/real_time", realTime)) {
//       Serial.println(realTime + " - successfully saved to: " + fbdo.dataPath());
//       Serial.println(" (" + fbdo.dataType() + ")");
//     } else {
//       Serial.println("Failed to save real-time data: " + fbdo.errorReason());
//     }

//   }
// }