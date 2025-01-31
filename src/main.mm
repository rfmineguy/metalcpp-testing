#import <Metal/Metal.h>
#import <QuartzCore/CAMetalLayer.h>
#import <Cocoa/Cocoa.h>
#import "MetalView.h"

int main() {
	NSApplication *app = [NSApplication sharedApplication];
	NSRect frame = NSMakeRect(0, 0, 800, 600);
	NSWindow *window = [[NSWindow alloc] initWithContentRect:frame
                                                       styleMask:(NSWindowStyleMaskTitled |
                                                                  NSWindowStyleMaskClosable |
                                                                  NSWindowStyleMaskResizable)
																											 backing:NSBackingStoreBuffered
																											 defer:NO];
	MetalView *metalView = [[MetalView alloc] initWithFrame:frame];
	[window setTitle: @"Window"];
	[window setContentView:metalView];
	[window makeKeyAndOrderFront:nil];
	NSLog(@"Window is key: %d", [window isKeyWindow]);

	// Setup menu
	[NSApp setMainMenu:[[NSMenu alloc] init]];
	NSMenuItem* appMenuItem = [[NSMenuItem alloc] init];
	NSMenu *appMenu = [[NSMenu alloc] initWithTitle:@"Application"];
	[appMenu addItem:[[NSMenuItem alloc] initWithTitle:@"Quit"
	 																		 action:@selector(terminate:) 
																			 keyEquivalent:@"q"]];

	[appMenuItem setSubmenu:appMenu];
	[[NSApp mainMenu] addItem:appMenuItem];

	NSLog(@"Should be running");
	[app setActivationPolicy:NSApplicationActivationPolicyRegular];
	[app activateIgnoringOtherApps:YES];
	[app run];

	[metalView dealloc];
}
