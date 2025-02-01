#import <Metal/Metal.h>
#import <QuartzCore/CAMetalLayer.h>
#import <Cocoa/Cocoa.h>
#import "MetalView.h"
#import "AppDelegate.h"

int main() {
	NSApplication *app = [NSApplication sharedApplication];
    AppDelegate *delegate = [[AppDelegate alloc] init];

	NSLog(@"Should be running");
	[app setActivationPolicy:NSApplicationActivationPolicyRegular];
	[app activateIgnoringOtherApps:YES];
    [app setDelegate: delegate];
	[app run];

    [app dealloc];
    [delegate dealloc];
    
    NSLog(@"Application finished");
}
