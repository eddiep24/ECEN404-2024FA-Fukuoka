import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:volume_controller/volume_controller.dart';
import 'dart:math';
import 'dart:async';
import 'glucose_graph.dart';
import 'glucose_prediction_service.dart';

class AnalyticsPage extends StatefulWidget {
  final String childKey;

  AnalyticsPage(this.childKey);

  @override
  _AnalyticsPageState createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  late DataSnapshot snapshot;
  final VolumeController _volumeController = VolumeController();
  Timer? _volumeTimer;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _volumeTimer?.cancel();
    super.dispose();
  }

  double calculateMean(List<double> values) {
    if (values.isEmpty) return 0.0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  double calculateMedian(List<double> values) {
    if (values.isEmpty) return 0.0;
    List<double> sortedValues = List.from(values)..sort();
    int middle = sortedValues.length ~/ 2;

    if (sortedValues.length % 2 == 1) {
      return sortedValues[middle];
    } else {
      return (sortedValues[middle - 1] + sortedValues[middle]) / 2.0;
    }
  }

  double calculateStandardDeviation(List<double> values, double mean) {
    if (values.isEmpty) return 0.0;
    try {
      double sumOfSquaredDifferences = values
          .map((value) => pow(value - mean, 2).toDouble())
          .reduce((a, b) => a + b);

      return sqrt(sumOfSquaredDifferences / values.length);
    } catch (e) {
      print('Error calculating standard deviation: $e');
      return 0.0;
    }
  }

  double calculateCV(double standardDeviation, double mean) {
    if (mean == 0) return 0.0;
    return (standardDeviation / mean) * 100;
  }

  List<double> calculateRateOfChange(List<Map<String, dynamic>> data) {
    if (data.length < 2) return [];
    List<double> rates = [];
    
    try {
      for (int i = 1; i < data.length; i++) {
        DateTime time1 = GlucosePredictionService.parseTimestamp(data[i - 1]['time']);
        DateTime time2 = GlucosePredictionService.parseTimestamp(data[i]['time']);
        double glucose1 = data[i - 1]['glucose'] as double? ?? 0.0;
        double glucose2 = data[i]['glucose'] as double? ?? 0.0;
        
        double timeDiff = time2.difference(time1).inMinutes.toDouble();
        if (timeDiff > 0) {
          rates.add((glucose2 - glucose1) / timeDiff);
        }
      }
    } catch (e) {
      print('Error calculating rate of change: $e');
    }
    return rates;
  }

  double calculateTimeInRange(List<double> values, double lowThreshold, double highThreshold) {
    if (values.isEmpty) return 0.0;
    int inRange = values.where((v) => v >= lowThreshold && v <= highThreshold).length;
    return (inRange / values.length) * 100;
  }

  double calculateFBG(List<Map<String, dynamic>> data) {
    if (data.isEmpty) return 0.0;
    
    try {
      var morningReadings = data.where((reading) {
        var time = GlucosePredictionService.parseTimestamp(reading['time']);
        return time.hour >= 4 && time.hour <= 8;
      });
      
      if (morningReadings.isEmpty) return 0.0;
      return calculateMean(morningReadings.map((r) => r['glucose'] as double? ?? 0.0).toList());
    } catch (e) {
      print('Error calculating FBG: $e');
      return 0.0;
    }
  }

  List<double> calculatePostMealGlucose(List<Map<String, dynamic>> data) {
    if (data.length < 2) return [];
    List<double> postMealReadings = [];
    
    try {
      for (int i = 0; i < data.length - 1; i++) {
        double currentGlucose = data[i]['glucose'] as double? ?? 0.0;
        double nextGlucose = data[i + 1]['glucose'] as double? ?? 0.0;
        
        if (nextGlucose - currentGlucose > 2.0) {
          var spikeTime = GlucosePredictionService.parseTimestamp(data[i + 1]['time']);
          var twoHoursLater = spikeTime.add(Duration(hours: 2));
          
          Map<String, dynamic>? closestReading;
          Duration smallestDiff = Duration(minutes: 30);
          
          for (var reading in data) {
            var readingTime = GlucosePredictionService.parseTimestamp(reading['time']);
            var diff = readingTime.difference(twoHoursLater).abs();
            
            if (diff < smallestDiff) {
              smallestDiff = diff;
              closestReading = reading;
            }
          }
          
          if (closestReading != null) {
            postMealReadings.add(closestReading['glucose'] as double? ?? 0.0);
          }
        }
      }
    } catch (e) {
      print('Error calculating post-meal glucose: $e');
    }
    return postMealReadings;
  }

  // Calculate hypoglycemic events safely
  Map<String, dynamic> calculateHypoEvents(List<double> values) {
    if (values.isEmpty) return {'count': 0, 'percentage': 0.0};
    int hypoCount = values.where((v) => v < 3.9).length;
    return {
      'count': hypoCount,
      'percentage': (hypoCount / values.length) * 100
    };
  }

  Widget buildStatCard(String title, String value, {String? subtitle}) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (subtitle != null) ...[
              SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
      Text(
        widget.childKey,
        style: TextStyle(color: Colors.white),  // Add this style
      ),

            IconButton(
              icon: Icon(Icons.refresh, color: Colors.white),
              onPressed: () {
                FirebaseDatabase.instance
                    .reference()
                    .child(widget.childKey)
                    .once()
                    .then((event) {
                  setState(() {
                    snapshot = event.snapshot;
                  });
                }).catchError((error) {
                  print("Error fetching data: $error");
                });
              },
            ),
          ],
        ),
      ),
      body: FutureBuilder<DataSnapshot>(
        future: FirebaseDatabase.instance
            .reference()
            .child(widget.childKey)
            .once()
            .then((event) => event.snapshot),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          
          if (!snapshot.hasData || snapshot.data?.value == null) {
            return Center(child: Text('No data available.'));
          }

          try {
            Map<dynamic, dynamic> data = snapshot.data!.value as Map<dynamic, dynamic>;
            List<Map<String, dynamic>> glucoseData = [];
            
            // Safely process data
            data.forEach((key, value) {
              if (key.toString() != 'time_created' && value is Map) {
                try {
                  double voltage = (value['voltage'] as num?)?.toDouble() ?? 0.0;
                  // print(voltage);
                  if (voltage < 0) {
                    voltage *= -1;
                  }
                  glucoseData.add({
                    'time': key.toString(),
                    'glucose': voltage
                  });
                } catch (e) {
                  print('Error processing entry $key: $e');
                }
              }
            });

            if (glucoseData.isEmpty) {
              return Center(child: Text('No valid glucose readings available.'));
            }

            glucoseData.sort((a, b) {
              try {
                return GlucosePredictionService.parseTimestamp(a['time'])
                    .compareTo(GlucosePredictionService.parseTimestamp(b['time']));
              } catch (e) {
                return 0;
              }
            });

            List<double> glucoseValues = glucoseData
                .map((entry) => entry['glucose'] as double)
                .where((value) => value >= 0)  
                .toList();

            if (glucoseValues.isEmpty) {
              return Center(child: Text('No valid glucose values available.'));
            }

            double mean = calculateMean(glucoseValues);
            print("Mean for this observation:");
            print(mean);
            double stdDev = calculateStandardDeviation(glucoseValues, mean);
            List<double> rateOfChange = calculateRateOfChange(glucoseData);
            double timeInRange = calculateTimeInRange(glucoseValues, 3.9, 10.0);
            var hypoEvents = calculateHypoEvents(glucoseValues);

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      'Glucose Level vs Time',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  AspectRatio(
                    aspectRatio: 1.5,
                    child: GlucoseGraph(glucoseData, 
                      GlucosePredictionService.calculatePredictions(glucoseData)),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: GridView.count(
                      crossAxisCount: 2,
                      childAspectRatio: 1.5,
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      children: [
                        buildStatCard(
                          'Fasting Blood Glucose',
                          '${calculateFBG(glucoseData).toStringAsFixed(1)} mmol/L',
                          subtitle: '4am-8am readings'
                        ),
                        buildStatCard(
                          'Post-Meal Average',
                          '${calculateMean(calculatePostMealGlucose(glucoseData)).toStringAsFixed(1)} mmol/L',
                          subtitle: '2hr after meals'
                        ),
                        buildStatCard(
                          'Glucose Variability',
                          '${stdDev.toStringAsFixed(1)} mmol/L',
                          subtitle: 'Standard deviation'
                        ),
                        buildStatCard(
                          'Hypoglycemic Events',
                          '${hypoEvents['count']} events',
                          subtitle: '${hypoEvents['percentage'].toStringAsFixed(1)}% of readings'
                        ),
                        buildStatCard(
                          'Average Glucose',
                          '${mean.toStringAsFixed(1)} mmol/L',
                          subtitle: 'Overall average'
                        ),
                        buildStatCard(
                          'Time in Range',
                          '${timeInRange.toStringAsFixed(1)}%',
                          subtitle: '3.9-10.0 mmol/L'
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          } catch (e) {
            print('Error building analytics view: $e');
            return Center(child: Text('Error processing glucose data'));
          }
        },
      ),
    );
  }
}