#import "MetalView.h"
#include "stb_image.h"

@implementation MetalView {
    id<MTLRenderPipelineState> _pipelineState;
    CADisplayLink *_displayLink;
    id<MTLBuffer> _vertexBuffer;
    id<MTLLibrary> _library;
    id<MTLFunction> _vertexFunction, _fragFunction;

    id<MTLTexture> _texture;
    int _textureWidth, _textureHeight, _textureChannels;
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

        //https://developer.apple.com/documentation/xcode/capturing-a-metal-workload-programmatically
        MTLCaptureManager* captureManager = [MTLCaptureManager sharedCaptureManager];
        if ([captureManager supportsDestination: MTLCaptureDestinationGPUTraceDocument]) {
            NSLog(@"Supports GPU trace doc");
        }
        else {
            NSLog(@"Doesnt support GPU trace doc");
        }

        // Create a capture descriptor
        NSFileManager *fm = [NSFileManager defaultManager];
        NSArray *docsDirs = [fm URLsForDirectory:NSDocumentDirectory inDomains: NSUserDomainMask];
        NSURL *docsDir = docsDirs[0];
        NSString *docsPath = [docsDir path];
        
        NSString *savePath = [docsPath stringByAppendingString: @"/capture.gputrace"];
        NSURL *pURL = [[NSURL alloc] initFileURLWithPath: savePath];
        NSError *error = nil;

#ifdef FRAME_CAPTURE
        // Delete the file at the specified path
        BOOL success = [fm removeItemAtPath:savePath error:&error];
        if (success) {
            NSLog(@"File deleted successfully.");
        } else {
            NSLog(@"No capture file to remove %@", error.localizedDescription);
        }

        MTLCaptureDescriptor *captureDescriptor = [[MTLCaptureDescriptor alloc] init];
        captureDescriptor.captureObject = self.device;
        captureDescriptor.destination = MTLCaptureDestinationGPUTraceDocument;
        captureDescriptor.outputURL = pURL;

        @try {
            // Start the capture
            NSError *error;
            [captureManager startCaptureWithDescriptor:captureDescriptor error:&error];
            [captureDescriptor dealloc];
            NSLog(@"[MetalView] Started capture: %@", error);
        } @catch (NSException *exception) {
            NSLog(@"Error when trying to capture: %@", exception);
            abort();
        }
        NSLog(@"[MetalView] Is capturing? %d", [captureManager isCapturing]);
#endif

        self.commandQueue = [self.device newCommandQueue];

        [self createTexture];
        [self createSquare];
        [self setupPipeline];
        [self setupDisplayLink];
    }
    
    NSLog(@"[MetalView] Initialized");
    return self;
}
- (void)dealloc {
#ifdef FRAME_CAPTURE
    MTLCaptureManager *captureManager = [MTLCaptureManager sharedCaptureManager];
    NSLog(@"[MetalView] Is capturing? %d", [captureManager isCapturing]);
    [captureManager stopCapture];
    NSLog(@"[MetalView] Stopped capture");
#endif

    [_texture release];
    _texture = nil;
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
    NSLog(@"[MetalView]: Deallocated fully");
    // [super dealloc];
}
- (void)createTexture {
    stbi_set_flip_vertically_on_load(true);
    NSBundle* mainBundle = [NSBundle mainBundle];
    NSString* path = [mainBundle pathForResource: @"assets/mc_grass" ofType:@"jpeg"];

    unsigned char* image = stbi_load([path UTF8String], &_textureWidth, &_textureHeight, &_textureChannels, STBI_rgb_alpha);
    if (image == nil) {
        NSLog(@"Image load failed, reason = %s for path: %s", stbi_failure_reason(), [path UTF8String]);
        exit(1);
    }
    
    MTLTextureDescriptor* textDesc = [[MTLTextureDescriptor alloc] init];
    [textDesc setPixelFormat: MTLPixelFormatBGRA8Unorm];
    [textDesc setWidth: _textureWidth];
    [textDesc setHeight: _textureHeight];
    
    _texture = [self.device newTextureWithDescriptor: textDesc];

    MTLRegion region = MTLRegionMake2D(0, 0, _textureWidth, _textureHeight);
    [_texture replaceRegion:region mipmapLevel: 0 withBytes: image bytesPerRow: 4 * _textureWidth];
    [textDesc release];
    stbi_image_free(image);
    NSLog(@"[MetalView] Created texture");
}
- (void)createSquare {
    // float squareVertices[3][6] = {
    //     {-0.5f, -0.5f, 0.0f, 1.0f, 1.0f, 1.0f},
    //     { 0.5f, -0.5f, 0.0f, 1.0f, 1.0f, 1.0f},
    //     { 0.0f,  0.5f, 0.0f, 1.0f, 1.0f, 1.0f}
    // };

    float squareVertices[][6] {
        {-0.5, -0.5,  0.5, 1.0f, 0.0f, 0.0f}, // float4 (position), float2 (uv te cooord)
        {-0.5,  0.5,  0.5, 1.0f, 0.0f, 1.0f},
        { 0.5,  0.5,  0.5, 1.0f, 1.0f, 1.0f},
        {-0.5, -0.5,  0.5, 1.0f, 0.0f, 0.0f},
        { 0.5,  0.5,  0.5, 1.0f, 1.0f, 1.0f},
        { 0.5, -0.5,  0.5, 1.0f, 1.0f, 0.0f}
    };
    _vertexBuffer = [self.device newBufferWithBytes:squareVertices length:sizeof(squareVertices) options: MTLResourceStorageModeShared];
    NSLog(@"[Triangle] Create triangle vertex buffer");
}
- (void)setupPipeline {
    NSError* error = nil;
    NSURL* url = [NSURL fileURLWithPath:@"default.metallib"];
    NSLog(@"url: %@", url);
    _library = [self.device newLibraryWithURL:url error:&error];
    // _library = [self.device newLibraryWithFile:@"default.metallib"];
    _vertexFunction = [_library newFunctionWithName:@"vertexShader"];
    _fragFunction = [_library newFunctionWithName:@"fragmentShader"];
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
    vertexDescriptor.attributes[1].format = MTLVertexFormatFloat2;
    vertexDescriptor.attributes[1].offset = 16; // After 4 floats (16 bytes) for position
    vertexDescriptor.attributes[1].bufferIndex = 0; // Attribute 1 is in the first buffer
    
    // Define the layout of the vertex buffer (stride = 32 bytes: 16 for position + 16 for color)
    vertexDescriptor.layouts[0].stride = 24;
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
    
    // NSLog(@"[Render] Begin");
    MTLRenderPassDescriptor *passDescriptor = [MTLRenderPassDescriptor renderPassDescriptor];
    passDescriptor.colorAttachments[0].texture = drawable.texture;
    passDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
    passDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.5, 0.4, 0.1, 1);
    passDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;

    // Command buffer
    id<MTLCommandBuffer> commandBuffer = [self.commandQueue commandBuffer];
    id<MTLRenderCommandEncoder> encoder = [commandBuffer renderCommandEncoderWithDescriptor:passDescriptor];
    [encoder setRenderPipelineState: _pipelineState];
    [encoder setVertexBuffer:_vertexBuffer offset:0 atIndex:0];
    MTLPrimitiveType triangleType = MTLPrimitiveTypeTriangle;
    NSUInteger vertStart = 0;
    NSUInteger vertCount = 6;
    [encoder setFragmentTexture: _texture atIndex: 0];
    [encoder drawPrimitives:triangleType vertexStart:vertStart vertexCount:vertCount];
    [encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];
    [encoder endEncoding];

    [commandBuffer presentDrawable:drawable];
    [commandBuffer commit];
    [commandBuffer waitUntilCompleted];
#ifdef FRAME_CAPTURE
    [[NSApplication sharedApplication] terminate: nil];
#endif

    // [passDescriptor release];
    // NSLog(@"[Render] End");
}
@end
