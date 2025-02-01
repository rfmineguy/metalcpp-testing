#import "AppDelegate.h"
#import <Cocoa/Cocoa.h>
#import "MetalView.h"

@implementation AppDelegate {
    MetalView *_metalView;
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    // Create the main window
    self.window = [[NSWindow alloc] initWithContentRect:NSMakeRect(100, 100, 600, 400)
                                              styleMask:(NSWindowStyleMaskTitled |
                                                         NSWindowStyleMaskResizable |
                                                         NSWindowStyleMaskClosable)
                                                backing:NSBackingStoreBuffered
                                                  defer:NO];
    
    [self.window setTitle:@"Metal Test"];
    [self.window setDelegate:self]; // Set the delegate to listen for resize events
    [self.window makeKeyAndOrderFront:nil];
    
    NSRect frame = NSMakeRect(0, 0, 800, 600);
    _metalView = [[MetalView alloc] initWithFrame:frame];
    [self.window setContentView:_metalView];

	// Setup menu
	[NSApp setMainMenu:[[NSMenu alloc] init]];
	NSMenuItem* appMenuItem = [[NSMenuItem alloc] init];
	NSMenu *appMenu = [[NSMenu alloc] initWithTitle:@"Application"];
	[appMenu addItem:[[NSMenuItem alloc] initWithTitle:@"Quit"
                                                action:@selector(terminate:)
                                                keyEquivalent:@"q"]];
	[appMenuItem setSubmenu:appMenu];
	[[NSApp mainMenu] addItem:appMenuItem];
}

- (void)windowDidResize:(NSNotification *)notification {
    NSSize newSize = self.window.frame.size;
    NSLog(@"Window resized: Width = %f, Height = %f", newSize.width, newSize.height);
    _metalView.metalLayer.drawableSize = CGSizeMake(newSize.width, newSize.height);
}
- (void) applicationWillTerminate:(NSNotification *) notification {
    NSLog(@"Application terminating");
    [self dealloc];
}
- (void) dealloc {
    NSLog(@"Application: dealloc %@", _metalView);
    [_metalView dealloc];
    // [super dealloc];
}

@end
