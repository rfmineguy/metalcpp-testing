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
	id<MTLBuffer> _vertexBuffer;
	id<MTLLibrary> _library;
	id<MTLFunction> _vertexFunction, _fragFunction;
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

				[self createTriangle];
        [self setupPipeline];
				[self setupDisplayLink];
    }
		NSLog(@"[MetalView] Initialized");
    return self;
}
- (void)dealloc {
	[super dealloc];
	[_vertexBuffer release];
	_vertexBuffer = nil;
	[_displayLink invalidate];
	_displayLink = nil;
	[self.commandQueue release];
	self.commandQueue = nil;

	[_library release];
	_library = nil;
	[_vertexFunction release];
	_vertexFunction = nil;
	[_fragFunction release];
	_fragFunction = nil;
}
- (void)createTriangle {
	float triangleVertices[][3] = {
		{-0.5f, -0.5f, 0.0f},
		{ 0.5f, -0.5f, 0.0f},
		{ 0.0f,  0.5f, 0.0f}
	};
	_vertexBuffer = [self.device newBufferWithBytes:triangleVertices length:sizeof(triangleVertices) options: MTLResourceStorageModeShared];
	NSLog(@"[Triangle] Create triangle vertex buffer");
}
- (void)setupPipeline {
    NSError* error = nil;
    NSURL* url = [NSURL fileURLWithPath:@"../default.metallib"];
    NSLog(@"url = %@", url);
    _library = [self.device newLibraryWithURL:url error:&error];
    // _library = [self.device newLibraryWithFile:@"default.metallib"];
    _vertexFunction = [_library newFunctionWithName:@"vertex_main"];
    _fragFunction = [_library newFunctionWithName:@"fragment_main"];
    NSLog(@"[Pipeline] Setup shaders {library = %@}", _library);
    
    MTLRenderPipelineDescriptor *pipelineDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
		pipelineDescriptor.label = @"Triangle Rendering Pipeline";
    pipelineDescriptor.vertexFunction = _vertexFunction;
    pipelineDescriptor.fragmentFunction = _fragFunction;
    pipelineDescriptor.colorAttachments[0].pixelFormat = self.metalLayer.pixelFormat;
		NSLog(@"[Pipeline] Setup pipeline descriptor");

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
		NSLog(@"[Pipeline] Setup vertex descriptor and attached to the pipeline");

		_pipelineState = [self.device newRenderPipelineStateWithDescriptor:pipelineDescriptor error:&error];
		// [pipelineDescriptor release];
    if (!_pipelineState) {
        NSLog(@"Failed to create pipeline state: %@", error);
    }
		[vertexDescriptor release];
		[pipelineDescriptor release];
	NSLog(@"[Pipeline] Created pipeline state");
}
- (void)setupDisplayLink {
	_displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(render)];
	[_displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
	NSLog(@"[DisplayLink] Setup");
}

- (void)render {
    id<CAMetalDrawable> drawable = [self.metalLayer nextDrawable];
    if (!drawable) {
        NSLog(@"No drawable available!");
        return;
    }
    
		NSLog(@"[Render] Begin");
    MTLRenderPassDescriptor *passDescriptor = [MTLRenderPassDescriptor renderPassDescriptor];
    passDescriptor.colorAttachments[0].texture = drawable.texture;
    passDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
    passDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.5, 0.1, 0.1, 1);
    passDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;

    id<MTLCommandBuffer> commandBuffer = [self.commandQueue commandBuffer];
    id<MTLRenderCommandEncoder> encoder = [commandBuffer renderCommandEncoderWithDescriptor:passDescriptor];
		[encoder setRenderPipelineState: _pipelineState];
		[encoder setVertexBuffer:_vertexBuffer offset:0 atIndex:0];
		MTLPrimitiveType triangleType = MTLPrimitiveTypeTriangle;
		NSUInteger vertStart = 0;
		NSUInteger vertCount = 3;
		[encoder drawPrimitives:triangleType vertexStart:vertStart vertexCount:vertCount];
    [encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];
    [encoder endEncoding];

    [commandBuffer presentDrawable:drawable];
    [commandBuffer commit];
		[commandBuffer waitUntilCompleted];

		// [passDescriptor release];
		NSLog(@"[Render] End");
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

	[metalView dealloc];
}
