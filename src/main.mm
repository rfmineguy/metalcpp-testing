#import <Metal/Metal.h>
#import <QuartzCore/CAMetalLayer.h>
#import <Cocoa/Cocoa.h>

@interface MetalView : NSView
@property (nonatomic, strong) CAMetalLayer *metalLayer;
@property (nonatomic, strong) id<MTLDevice> device;
@property (nonatomic, strong) id<MTLCommandQueue> commandQueue;
- (void)render;
@end

@implementation MetalView {
	id<MTLRenderPipelineState> _pipelineState;
	CADisplayLink *_displayLink;
}
- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        self.wantsLayer = YES;
        self.layer = [CAMetalLayer layer];
        self.metalLayer = (CAMetalLayer *)self.layer;
        self.device = MTLCreateSystemDefaultDevice();
        self.metalLayer.device = self.device;
        self.metalLayer.pixelFormat = MTLPixelFormatBGRA8Unorm;
        self.commandQueue = [self.device newCommandQueue];

        [self setupPipeline];
				[self setupDisplayLink];
    }
    return self;
}
- (void)setupPipeline {
    id<MTLLibrary> library = [self.device newDefaultLibrary];
    id<MTLFunction> vertexFunction = [library newFunctionWithName:@"vertex_main"];
    id<MTLFunction> fragmentFunction = [library newFunctionWithName:@"fragment_main"];
    
    MTLRenderPipelineDescriptor *pipelineDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
    pipelineDescriptor.vertexFunction = vertexFunction;
    pipelineDescriptor.fragmentFunction = fragmentFunction;
    pipelineDescriptor.colorAttachments[0].pixelFormat = self.metalLayer.pixelFormat;

		 // Create the vertex descriptor to define the layout of vertex attributes
    MTLVertexDescriptor *vertexDescriptor = [[MTLVertexDescriptor alloc] init];
    
    // Define the layout for the position attribute (float4)
    vertexDescriptor.attributes[0].format = MTLVertexFormatFloat4;
    vertexDescriptor.attributes[0].offset = 0;
    vertexDescriptor.attributes[0].bufferIndex = 0; // Attribute 0 is in the first buffer
    
    // Define the layout for the color attribute (float4)
    vertexDescriptor.attributes[1].format = MTLVertexFormatFloat4;
    vertexDescriptor.attributes[1].offset = 16; // After 4 floats (16 bytes) for position
    vertexDescriptor.attributes[1].bufferIndex = 0; // Attribute 1 is in the first buffer
    
    // Define the layout of the vertex buffer (stride = 32 bytes: 16 for position + 16 for color)
    vertexDescriptor.layouts[0].stride = 32;
    vertexDescriptor.layouts[0].stepFunction = MTLVertexStepFunctionPerVertex;
    vertexDescriptor.layouts[0].stepRate = 1;

    // Set the vertex descriptor for the pipeline
    pipelineDescriptor.vertexDescriptor = vertexDescriptor;

		NSError *error = nil;
		_pipelineState = [self.device newRenderPipelineStateWithDescriptor:pipelineDescriptor error:&error];
    if (!_pipelineState) {
        NSLog(@"Failed to create pipeline state: %@", error);
    }
}
- (void)setupDisplayLink {
	_displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(render)];
	[_displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
}

- (void)render {
    id<CAMetalDrawable> drawable = [self.metalLayer nextDrawable];
    if (!drawable) {
        NSLog(@"No drawable available!");
        return;
    }
    
    MTLRenderPassDescriptor *passDescriptor = [MTLRenderPassDescriptor renderPassDescriptor];
    passDescriptor.colorAttachments[0].texture = drawable.texture;
    passDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
    passDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.1, 0.1, 0.1, 1);
    passDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;

    id<MTLCommandBuffer> commandBuffer = [self.commandQueue commandBuffer];
    id<MTLRenderCommandEncoder> encoder = [commandBuffer renderCommandEncoderWithDescriptor:passDescriptor];
    
    [encoder setRenderPipelineState:_pipelineState];
    [encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];
    [encoder endEncoding];

    [commandBuffer presentDrawable:drawable];
    [commandBuffer commit];
}
@end

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
}
