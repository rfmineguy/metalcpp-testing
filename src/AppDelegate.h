#import <Cocoa/Cocoa.h>

@interface AppDelegate : NSObject <NSApplicationDelegate, NSWindowDelegate>
@property (strong, nonatomic) NSWindow *window;
- (void)applicationDidFinishLaunching;
- (void)windowDidResize;
- (void)dealloc;
@end
