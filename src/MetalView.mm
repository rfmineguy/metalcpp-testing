#import "MetalView.h"
#include "VertexData.h"
#include "AAPLMathUtilities.h"
#include "stb_image.h"

@implementation MetalView {
    id<MTLRenderPipelineState> _pipelineState;
    CADisplayLink *_displayLink;
    id<MTLBuffer> _vertexBuffer, _transformationBuffer;
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

#if defined(FRAME_CAPTURE) && (FRAME_CAPTURE==1)
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
        [self createCube];
        [self setupPipeline];
        [self setupDisplayLink];
    }
    
    NSLog(@"[MetalView] Initialized");
    return self;
}
- (void)dealloc {
#if defined(FRAME_CAPTURE) && (FRAME_CAPTURE==1)
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
    VertexData squareVertices[6] {
         { { -0.5, -0.5, 0.0, 1.0}, {1.0, 1.0} },
         { { -0.5,  0.5, 0.0, 1.0}, {1.0, 0.0} },
         { {  0.5,  0.5, 0.0, 1.0}, {0.0, 0.0} },
         { { -0.5, -0.5, 0.0, 1.0}, {1.0, 1.0} },
         { {  0.5,  0.5, 0.0, 1.0}, {0.0, 0.0} },
         { {  0.5, -0.5, 0.0, 1.0}, {0.0, 1.0} },
    };
    _vertexBuffer = [self.device newBufferWithBytes:squareVertices length:sizeof(squareVertices) options: MTLResourceStorageModeShared];
    NSLog(@"[Triangle] Create triangle vertex buffer");
}
- (void)createCube {
    VertexData cubeVertices[36] {
        // Front face
        {{-0.5, -0.5, 0.5, 1.0}, {0.0, 0.0}},
        {{0.5, -0.5, 0.5, 1.0}, {1.0, 0.0}},
        {{0.5, 0.5, 0.5, 1.0}, {1.0, 1.0}},
        {{0.5, 0.5, 0.5, 1.0}, {1.0, 1.0}},
        {{-0.5, 0.5, 0.5, 1.0}, {0.0, 1.0}},
        {{-0.5, -0.5, 0.5, 1.0}, {0.0, 0.0}},

        // Back face
        {{0.5, -0.5, -0.5, 1.0}, {0.0, 0.0}},
        {{-0.5, -0.5, -0.5, 1.0}, {1.0, 0.0}},
        {{-0.5, 0.5, -0.5, 1.0}, {1.0, 1.0}},
        {{-0.5, 0.5, -0.5, 1.0}, {1.0, 1.0}},
        {{0.5, 0.5, -0.5, 1.0}, {0.0, 1.0}},
        {{0.5, -0.5, -0.5, 1.0}, {0.0, 0.0}},

        // Top face
        {{-0.5, 0.5, 0.5, 1.0}, {0.0, 0.0}},
        {{0.5, 0.5, 0.5, 1.0}, {1.0, 0.0}},
        {{0.5, 0.5, -0.5, 1.0}, {1.0, 1.0}},
        {{0.5, 0.5, -0.5, 1.0}, {1.0, 1.0}},
        {{-0.5, 0.5, -0.5, 1.0}, {0.0, 1.0}},
        {{-0.5, 0.5, 0.5, 1.0}, {0.0, 0.0}},

        // Bottom face
        {{-0.5, -0.5, -0.5, 1.0}, {0.0, 0.0}},
        {{0.5, -0.5, -0.5, 1.0}, {1.0, 0.0}},
        {{0.5, -0.5, 0.5, 1.0}, {1.0, 1.0}},
        {{0.5, -0.5, 0.5, 1.0}, {1.0, 1.0}},
        {{-0.5, -0.5, 0.5, 1.0}, {0.0, 1.0}},
        {{-0.5, -0.5, -0.5, 1.0}, {0.0, 0.0}},

        // Left face
        {{-0.5, -0.5, -0.5, 1.0}, {0.0, 0.0}},
        {{-0.5, -0.5, 0.5, 1.0}, {1.0, 0.0}},
        {{-0.5, 0.5, 0.5, 1.0}, {1.0, 1.0}},
        {{-0.5, 0.5, 0.5, 1.0}, {1.0, 1.0}},
        {{-0.5, 0.5, -0.5, 1.0}, {0.0, 1.0}},
        {{-0.5, -0.5, -0.5, 1.0}, {0.0, 0.0}},

        // Right face
        {{0.5, -0.5, 0.5, 1.0}, {0.0, 0.0}},
        {{0.5, -0.5, -0.5, 1.0}, {1.0, 0.0}},
        {{0.5, 0.5, -0.5, 1.0}, {1.0, 1.0}},
        {{0.5, 0.5, -0.5, 1.0}, {1.0, 1.0}},
        {{0.5, 0.5, 0.5, 1.0}, {0.0, 1.0}},
        {{0.5, -0.5, 0.5, 1.0}, {0.0, 0.0}},
    };
    _vertexBuffer = [self.device newBufferWithBytes:cubeVertices length:sizeof(cubeVertices) options: MTLResourceStorageModeShared];
    _transformationBuffer = [self.device newBufferWithLength:sizeof(TransformationData) options:MTLResourceStorageModeShared];
    NSLog(@"[Triangle] Create triangle vertex buffer");
}
- (void)setupPipeline {
    NSError* error = nil;
    NSURL* url = [NSURL fileURLWithPath:@"default.metallib"];
    NSLog(@"url: %@", url);
    _library = [self.device newLibraryWithURL:url error:&error];
    _vertexFunction = [_library newFunctionWithName:@"cube_vertex"];
    _fragFunction = [_library newFunctionWithName:@"cube_fragment"];
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
    vertexDescriptor.attributes[0].offset = offsetof(VertexData, position);
    vertexDescriptor.attributes[0].bufferIndex = 0; // Attribute 0 is in the first buffer
    
    // Define the layout for the color attribute (float2)
    vertexDescriptor.attributes[1].format = MTLVertexFormatFloat2;
    vertexDescriptor.attributes[1].offset = offsetof(VertexData, texCoord); // After 4 floats (16 bytes) for position
    vertexDescriptor.attributes[1].bufferIndex = 0; // Attribute 1 is in the first buffer
    
    // Define the layout of the vertex buffer (stride = 24 bytes: 16 for position + 8 for tex coord)
    NSLog(@"size: %lu", sizeof(VertexData));
    vertexDescriptor.layouts[0].stride = sizeof(VertexData);
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

    // Transformation math
    matrix_float4x4 transMat = matrix4x4_translation(0, 0, -1.0);
    float rads = 30 * M_PI / 180;
    matrix_float4x4 rotMat = matrix4x4_rotation(rads, 0, 1, 0);
    matrix_float4x4 modelMat = simd_mul(transMat, rotMat);
    
    simd::float3 R = simd::float3 {1, 0, 0}; // Unit-Right
    simd::float3 U = simd::float3 {0, 1, 0}; // Unit-Up
    simd::float3 F = simd::float3 {0, 0,-1}; // Unit-Forward
    simd::float3 P = simd::float3 {0, 0, 1}; // Camera Position in World Space

    matrix_float4x4 viewMatrix = matrix_make_rows(R.x, R.y, R.z, simd_dot(-R, P),
                                                  U.x, U.y, U.z, simd_dot(-U, P),
                                                 -F.x,-F.y,-F.z, simd_dot( F, P),
                                                  0, 0, 0, 1);

    float aspect = (_metalLayer.frame.size.width / _metalLayer.frame.size.height);
    float fov = 90 * (M_PI / 180.f);
    float nearZ = 0.1f;
    float farZ = 100.0f;

    matrix_float4x4 perspMatrix = matrix_perspective_right_hand(fov, aspect, nearZ, farZ);

    TransformationData tdata = { modelMat, viewMatrix, perspMatrix };
    memcpy([_transformationBuffer contents], &tdata, sizeof(tdata));
    
    // Command buffer
    id<MTLCommandBuffer> commandBuffer = [self.commandQueue commandBuffer];
    id<MTLRenderCommandEncoder> encoder = [commandBuffer renderCommandEncoderWithDescriptor:passDescriptor];

    [encoder setRenderPipelineState: _pipelineState];
    [encoder setVertexBuffer:_vertexBuffer offset:0 atIndex:0];
    [encoder setVertexBuffer:_transformationBuffer offset:0 atIndex:1];
    MTLPrimitiveType triangleType = MTLPrimitiveTypeTriangle;
    NSUInteger vertStart = 0;
    NSUInteger vertCount = 36;
    [encoder setFragmentTexture: _texture atIndex: 0];
    [encoder drawPrimitives:triangleType vertexStart:vertStart vertexCount:vertCount];
    // [encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];
    [encoder endEncoding];

    [commandBuffer presentDrawable:drawable];
    [commandBuffer commit];
    [commandBuffer waitUntilCompleted];
#if defined(FRAME_CAPTURE) && (FRAME_CAPTURE==1)
    [[NSApplication sharedApplication] terminate: nil];
#endif

    // [passDescriptor release];
    // NSLog(@"[Render] End");
}
@end
