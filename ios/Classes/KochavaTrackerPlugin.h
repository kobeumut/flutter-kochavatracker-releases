#import <Flutter/Flutter.h>

// Declare Plugin
@interface KochavaTrackerPlugin : NSObject<FlutterPlugin>

// Method channel property for native to dart communication.
@property (strong, nonatomic) FlutterMethodChannel *channel;

- (instancetype)initWithChannel:(FlutterMethodChannel *)channel;

@end
