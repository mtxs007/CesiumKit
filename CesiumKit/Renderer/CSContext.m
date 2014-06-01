//
//  CSContext.m
//  CesiumKit
//
//  Created by Ryan Walklin on 7/05/14.
//  Copyright (c) 2014 Ryan Walklin. All rights reserved.
//

#import "CSContext.h"

#import "CSTypedArray.h"

@import GLKit;

#import "CSUniformState.h"
#import "CSPassState.h"
#import "CSRenderState.h"

#import "CSCartesian4.h"


@interface CSContext () {
    
    UInt32 *_nextPickColor;
}

/**
 * DOC_TBA
 * @performance DOC_TBA: slow.
 * @type {Boolean}
 */
@property BOOL validateFramebuffer;

/**
 * DOC_TBA
 * @performance DOC_TBA: slow.
 * @type {Boolean}
 */
@property BOOL validateShaderProgram;

@property BOOL logShaderCompilation;

@property (nonatomic) CSRenderState *currentRenderState;
@property (nonatomic) id currentFrameBuffer;
@property (nonatomic) UInt32 maxFrameTextureUnitIndex;

@property (nonatomic) NSMutableArray *pickObjects;

@property (readonly) NSArray *cachedGLESExtensions;

-(CSBuffer *)createBuffer:(UInt32)bufferTarget size:(UInt32)size usage:(enum CSBufferUsage)usage;

-(BOOL)checkGLExtension:(NSString *)glExtension;
-(NSArray *)getGLExtensions;

@end

@implementation CSContext

-(id)initWithGLKView:(GLKView *)glView
{
    self = [super init];
    if (self)
    {
        NSAssert(glView != nil, @"Nil GLView passed");
        _glkView = glView;
        _validateFramebuffer = NO;
        _validateShaderProgram = NO;
        
        
        //options = clone(options, true);
        //options = defaultValue(options, {});
        //options.allowTextureFilterAnisotropic = defaultValue(options.allowTextureFilterAnisotropic, true);
        //var webglOptions = defaultValue(options.webgl, {});
        
        // Override select WebGL defaults
        //webglOptions.alpha = defaultValue(webglOptions.alpha, false); // WebGL default is true
        // TODO: WebGL default is false. This works around a bug in Canary and can be removed when fixed: https://code.google.com/p/chromium/issues/detail?id=335273
        //webglOptions.stencil = defaultValue(webglOptions.stencil, false);
        //webglOptions.failIfMajorPerformanceCaveat = defaultValue(webglOptions.failIfMajorPerformanceCaveat, true); // WebGL default is false
        
        _guid = [[NSUUID UUID] UUIDString];
        
        // Validation and logging disabled by default for speed.
        _validateFramebuffer = NO;
        _validateShaderProgram = NO;
        _logShaderCompilation = NO;
                
        //this._shaderCache = new ShaderCache(this);
        _glVersion = [[NSString alloc] initWithCString:(const char *)glGetString(GL_VERSION) encoding:NSASCIIStringEncoding];
        _vendor = [[NSString alloc] initWithCString:(const char *)glGetString(GL_VENDOR) encoding:NSASCIIStringEncoding];
        _renderer = [[NSString alloc] initWithCString:(const char *)glGetString(GL_RENDERER) encoding:NSASCIIStringEncoding];
        _shadingLanguageVersion = [[NSString alloc] initWithCString:(const char *)glGetString(GL_SHADING_LANGUAGE_VERSION) encoding:NSASCIIStringEncoding];
        glGetIntegerv(GL_RED_BITS, &_redBits);
        glGetIntegerv(GL_GREEN_BITS, &_greenBits);
        glGetIntegerv(GL_BLUE_BITS, &_blueBits);
        glGetIntegerv(GL_ALPHA_BITS, &_alphaBits);
        glGetIntegerv(GL_DEPTH_BITS, &_depthBits);
        glGetIntegerv(GL_STENCIL_BITS, &_stencilBits);

        glGetIntegerv(GL_MAX_COMBINED_TEXTURE_IMAGE_UNITS, &_maximumCombinedTextureImageUnits);
        glGetIntegerv(GL_MAX_CUBE_MAP_TEXTURE_SIZE, &_maximumCubeMapSize);
        glGetIntegerv(GL_MAX_FRAGMENT_UNIFORM_VECTORS, &_maximumFragmentUniformVectors);
        glGetIntegerv(GL_MAX_TEXTURE_IMAGE_UNITS, &_maximumTextureImageUnits);
        glGetIntegerv(GL_MAX_RENDERBUFFER_SIZE, &_maximumRenderBufferSize);
        glGetIntegerv(GL_MAX_TEXTURE_SIZE, &_maximumTextureSize);
        glGetIntegerv(GL_MAX_VARYING_VECTORS, &_maximumVaryingVectors);
        glGetIntegerv(GL_MAX_VERTEX_ATTRIBS, &_maximumVertexAttributes);
        glGetIntegerv(GL_MAX_VERTEX_TEXTURE_IMAGE_UNITS, &_maximumVertexTextureImageUnits);
        glGetIntegerv(GL_MAX_FRAGMENT_UNIFORM_VECTORS, &_maximumFragmentUniformVectors);
        glGetIntegerv(GL_MAX_VERTEX_UNIFORM_VECTORS, &_maximumVertexUniformVectors);
        glGetIntegerv(GL_ALIASED_LINE_WIDTH_RANGE, &_aliasedLineWidthRange);
        glGetIntegerv(GL_ALIASED_POINT_SIZE_RANGE, &_aliasedPointSizeRange);
        
        GLint viewPortDims[2];
        glGetIntegerv(GL_MAX_VIEWPORT_DIMS, (GLint *)&viewPortDims);
        _maximumViewportDimensions = CGSizeMake(viewPortDims[0], viewPortDims[1]);
        
        
//        this._antialias = gl.getContextAttributes().antialias;
        
        // Query and initialize extensions
        _standardDerivatives = [self checkGLExtension:@"GL_OES_standard_derivatives"];
        _elementIndexUint = ([self checkGLExtension:@"GL_OES_element_index_uint"]  || _glkView.context.API == kEAGLRenderingAPIOpenGLES3);
        _depthTexture = ([self checkGLExtension:@"GL_OES_depth_texture"]  || _glkView.context.API == kEAGLRenderingAPIOpenGLES3);
        _floatingPointTexture = ([self checkGLExtension:@"GL_OES_texture_float"]  || _glkView.context.API == kEAGLRenderingAPIOpenGLES3);
        
        _textureFilterAnisotropic = ([self checkGLExtension:@"GL_EXT_texture_filter_anisotropic"]);
        glGetIntegerv(GL_MAX_TEXTURE_MAX_ANISOTROPY_EXT, &_maximumTextureFilterAnisotropy);
       
        _vertexArrayObject = ([self checkGLExtension:@"GL_OES_vertex_array_object"] || _glkView.context.API == kEAGLRenderingAPIOpenGLES3);
        _fragmentDepth = ([self checkGLExtension:@"GL_EXT_frag_depth"] || _glkView.context.API == kEAGLRenderingAPIOpenGLES3);
        
        _drawBuffers = [self checkGLExtension:@"GL_EXT_draw_buffers"];

        /*this._maximumDrawBuffers = defined(this._drawBuffers) ? gl.getParameter(this._drawBuffers.MAX_DRAW_BUFFERS_WEBGL) : 1;*/
        //_maximumColorAttachments = glGetIntegerv(GL_MAX_COLOR_ATTACHMENTS_EXT, <#GLint *params#>)
        //this._maximumColorAttachments = defined(this._drawBuffers) ? gl.getParameter(this._drawBuffers.MAX_COLOR_ATTACHMENTS_WEBGL) : 1; // min when supported: 4
    
        GLfloat cc[4];
        glGetFloatv(GL_COLOR_CLEAR_VALUE, (GLfloat *)&cc);
        _clearColor = [CSCartesian4 cartesian4WithRed:cc[0] green:cc[1] blue:cc[2] alpha:cc[3]];

        glGetFloatv(GL_DEPTH_CLEAR_VALUE, &_clearDepth);
        glGetIntegerv(GL_STENCIL_CLEAR_VALUE, &_clearStencil);
        
        _uniformState = [[CSUniformState alloc] init];
        _passState = [[CSPassState alloc] initWithContext:self];
        _renderState = [self createRenderState];
        
        _defaultPassState = _passState;
        _defaultRenderState = _renderState;
        _defaultTexture = nil;
        _defaultCubeMap = nil;
        
        _currentRenderState = _renderState;
        _currentFrameBuffer = nil;
        _maxFrameTextureUnitIndex = 0;
        
        _pickObjects = [NSMutableArray array];
        _nextPickColor = 0;

        _cache = [NSMutableArray array];
        
        //RenderState.apply(gl, rs, ps);

    }
    return self;
}

   /*

         * sp = context.createShaderProgram(vs, fs, attributes);
     *
    Context.prototype.createShaderProgram = function(vertexShaderSource, fragmentShaderSource, attributeLocations) {
        return new ShaderProgram(this._gl, this._logShaderCompilation, vertexShaderSource, fragmentShaderSource, attributeLocations);
    };
    
    function createBuffer(gl, bufferTarget, typedArrayOrSizeInBytes, usage) {
        var sizeInBytes;
        
        if (typeof typedArrayOrSizeInBytes === 'number') {
            sizeInBytes = typedArrayOrSizeInBytes;
        } else if (typeof typedArrayOrSizeInBytes === 'object' && typeof typedArrayOrSizeInBytes.byteLength === 'number') {
            sizeInBytes = typedArrayOrSizeInBytes.byteLength;
        } else {
            //>>includeStart('debug', pragmas.debug);
            throw new DeveloperError('typedArrayOrSizeInBytes must be either a typed array or a number.');
            //>>includeEnd('debug');
        }
        
        //>>includeStart('debug', pragmas.debug);
        if (sizeInBytes <= 0) {
            throw new DeveloperError('typedArrayOrSizeInBytes must be greater than zero.');
        }
        
        if (!BufferUsage.validate(usage)) {
            throw new DeveloperError('usage is invalid.');
        }
        //>>includeEnd('debug');
        
        var buffer = gl.createBuffer();
        gl.bindBuffer(bufferTarget, buffer);
        gl.bufferData(bufferTarget, typedArrayOrSizeInBytes, usage);
        gl.bindBuffer(bufferTarget, null);
        
        return new Buffer(gl, bufferTarget, sizeInBytes, usage, buffer);
    }
    
    /**
     * Creates a vertex buffer, which contains untyped vertex data in GPU-controlled memory.
     * <br /><br />
     * A vertex array defines the actual makeup of a vertex, e.g., positions, normals, texture coordinates,
     * etc., by interpreting the raw data in one or more vertex buffers.
     *
     * @memberof Context
     *
     * @param {ArrayBufferView|Number} typedArrayOrSizeInBytes A typed array containing the data to copy to the buffer, or a <code>Number</code> defining the size of the buffer in bytes.
     * @param {BufferUsage} usage Specifies the expected usage pattern of the buffer.  On some GL implementations, this can significantly affect performance.  See {@link BufferUsage}.
     *
     * @returns {VertexBuffer} The vertex buffer, ready to be attached to a vertex array.
     *
     * @exception {DeveloperError} The size in bytes must be greater than zero.
     * @exception {DeveloperError} Invalid <code>usage</code>.
     *
     * @see Context#createVertexArray
     * @see Context#createIndexBuffer
     * @see <a href='http://www.khronos.org/opengles/sdk/2.0/docs/man/glGenBuffer.xml'>glGenBuffer</a>
     * @see <a href='http://www.khronos.org/opengles/sdk/2.0/docs/man/glBindBuffer.xml'>glBindBuffer</a> with <code>ARRAY_BUFFER</code>
     * @see <a href='http://www.khronos.org/opengles/sdk/2.0/docs/man/glBufferData.xml'>glBufferData</a> with <code>ARRAY_BUFFER</code>
     *
     * @example
     * // Example 1. Create a dynamic vertex buffer 16 bytes in size.
     * var buffer = context.createVertexBuffer(16, BufferUsage.DYNAMIC_DRAW);
     *
     * ////////////////////////////////////////////////////////////////////////////////
     *
     * // Example 2. Create a dynamic vertex buffer from three floating-point values.
     * // The data copied to the vertex buffer is considered raw bytes until it is
     * // interpreted as vertices using a vertex array.
     * var positionBuffer = context.createVertexBuffer(new Float32Array([0, 0, 0]),
     *     BufferUsage.STATIC_DRAW);
     *
    Context.prototype.createVertexBuffer = function(typedArrayOrSizeInBytes, usage) {
        return createBuffer(this._gl, this._gl.ARRAY_BUFFER, typedArrayOrSizeInBytes, usage);
    };
    
    /**
     * Creates an index buffer, which contains typed indices in GPU-controlled memory.
     * <br /><br />
     * An index buffer can be attached to a vertex array to select vertices for rendering.
     * <code>Context.draw</code> can render using the entire index buffer or a subset
     * of the index buffer defined by an offset and count.
     *
     * @memberof Context
     *
     * @param {ArrayBufferView|Number} typedArrayOrSizeInBytes A typed array containing the data to copy to the buffer, or a <code>Number</code> defining the size of the buffer in bytes.
     * @param {BufferUsage} usage Specifies the expected usage pattern of the buffer.  On some GL implementations, this can significantly affect performance.  See {@link BufferUsage}.
     * @param {IndexDatatype} indexDatatype The datatype of indices in the buffer.
     *
     * @returns {IndexBuffer} The index buffer, ready to be attached to a vertex array.
     *
     * @exception {RuntimeError} IndexDatatype.UNSIGNED_INT requires OES_element_index_uint, which is not supported on this system.
     * @exception {DeveloperError} The size in bytes must be greater than zero.
     * @exception {DeveloperError} Invalid <code>usage</code>.
     * @exception {DeveloperError} Invalid <code>indexDatatype</code>.
     *
     * @see Context#createVertexArray
     * @see Context#createVertexBuffer
     * @see Context#draw
     * @see VertexArray
     * @see <a href='http://www.khronos.org/opengles/sdk/2.0/docs/man/glGenBuffer.xml'>glGenBuffer</a>
     * @see <a href='http://www.khronos.org/opengles/sdk/2.0/docs/man/glBindBuffer.xml'>glBindBuffer</a> with <code>ELEMENT_ARRAY_BUFFER</code>
     * @see <a href='http://www.khronos.org/opengles/sdk/2.0/docs/man/glBufferData.xml'>glBufferData</a> with <code>ELEMENT_ARRAY_BUFFER</code>
     *
     * @example
     * // Example 1. Create a stream index buffer of unsigned shorts that is
     * // 16 bytes in size.
     * var buffer = context.createIndexBuffer(16, BufferUsage.STREAM_DRAW,
     *     IndexDatatype.UNSIGNED_SHORT);
     *
     * ////////////////////////////////////////////////////////////////////////////////
     *
     * // Example 2. Create a static index buffer containing three unsigned shorts.
     * var buffer = context.createIndexBuffer(new Uint16Array([0, 1, 2]),
     *     BufferUsage.STATIC_DRAW, IndexDatatype.UNSIGNED_SHORT)
     *
    Context.prototype.createIndexBuffer = function(typedArrayOrSizeInBytes, usage, indexDatatype) {
        //>>includeStart('debug', pragmas.debug);
        if (!IndexDatatype.validate(indexDatatype)) {
            throw new DeveloperError('Invalid indexDatatype.');
        }
        //>>includeEnd('debug');
        
        if ((indexDatatype === IndexDatatype.UNSIGNED_INT) && !this.elementIndexUint) {
            throw new RuntimeError('IndexDatatype.UNSIGNED_INT requires OES_element_index_uint, which is not supported on this system.');
        }
        
        var bytesPerIndex = IndexDatatype.getSizeInBytes(indexDatatype);
        
        var gl = this._gl;
        var buffer = createBuffer(gl, gl.ELEMENT_ARRAY_BUFFER, typedArrayOrSizeInBytes, usage);
        var numberOfIndices = buffer.sizeInBytes / bytesPerIndex;
        
        defineProperties(buffer, {
        indexDatatype: {
            get : function() {
                return indexDatatype;
            }
        },
            bytesPerIndex : {
                get : function() {
                    return bytesPerIndex;
                }
            },
            numberOfIndices : {
                get : function() {
                    return numberOfIndices;
                }
            }
        });
        
        return buffer;
    };
    
    /**
     * Creates a vertex array, which defines the attributes making up a vertex, and contains an optional index buffer
     * to select vertices for rendering.  Attributes are defined using object literals as shown in Example 1 below.
     *
     * @memberof Context
     *
     * @param {Array} [attributes=undefined] An optional array of attributes.
     * @param {IndexBuffer} [indexBuffer=undefined] An optional index buffer.
     *
     * @returns {VertexArray} The vertex array, ready for use with drawing.
     *
     * @exception {DeveloperError} Attribute must have a <code>vertexBuffer</code>.
     * @exception {DeveloperError} Attribute must have a <code>componentsPerAttribute</code>.
     * @exception {DeveloperError} Attribute must have a valid <code>componentDatatype</code> or not specify it.
     * @exception {DeveloperError} Attribute must have a <code>strideInBytes</code> less than or equal to 255 or not specify it.
     * @exception {DeveloperError} Index n is used by more than one attribute.
     *
     * @see Context#createVertexArrayFromGeometry
     * @see Context#createVertexBuffer
     * @see Context#createIndexBuffer
     * @see Context#draw
     *
     * @example
     * // Example 1. Create a vertex array with vertices made up of three floating point
     * // values, e.g., a position, from a single vertex buffer.  No index buffer is used.
     * var positionBuffer = context.createVertexBuffer(12, BufferUsage.STATIC_DRAW);
     * var attributes = [
     *     {
     *         index                  : 0,
     *         enabled                : true,
     *         vertexBuffer           : positionBuffer,
     *         componentsPerAttribute : 3,
     *         componentDatatype      : ComponentDatatype.FLOAT,
     *         normalize              : false,
     *         offsetInBytes          : 0,
     *         strideInBytes          : 0 // tightly packed
     *     }
     * ];
     * var va = context.createVertexArray(attributes);
     *
     * ////////////////////////////////////////////////////////////////////////////////
     *
     * // Example 2. Create a vertex array with vertices from two different vertex buffers.
     * // Each vertex has a three-component position and three-component normal.
     * var positionBuffer = context.createVertexBuffer(12, BufferUsage.STATIC_DRAW);
     * var normalBuffer = context.createVertexBuffer(12, BufferUsage.STATIC_DRAW);
     * var attributes = [
     *     {
     *         index                  : 0,
     *         vertexBuffer           : positionBuffer,
     *         componentsPerAttribute : 3,
     *         componentDatatype      : ComponentDatatype.FLOAT
     *     },
     *     {
     *         index                  : 1,
     *         vertexBuffer           : normalBuffer,
     *         componentsPerAttribute : 3,
     *         componentDatatype      : ComponentDatatype.FLOAT
     *     }
     * ];
     * var va = context.createVertexArray(attributes);
     *
     * ////////////////////////////////////////////////////////////////////////////////
     *
     * // Example 3. Creates the same vertex layout as Example 2 using a single
     * // vertex buffer, instead of two.
     * var buffer = context.createVertexBuffer(24, BufferUsage.STATIC_DRAW);
     * var attributes = [
     *     {
     *         vertexBuffer           : buffer,
     *         componentsPerAttribute : 3,
     *         componentDatatype      : ComponentDatatype.FLOAT,
     *         offsetInBytes          : 0,
     *         strideInBytes          : 24
     *     },
     *     {
     *         vertexBuffer           : buffer,
     *         componentsPerAttribute : 3,
     *         componentDatatype      : ComponentDatatype.FLOAT,
     *         normalize              : true,
     *         offsetInBytes          : 12,
     *         strideInBytes          : 24
     *     }
     * ];
     * var va = context.createVertexArray(attributes);
     *
    Context.prototype.createVertexArray = function(attributes, indexBuffer) {
        return new VertexArray(this._gl, this._vertexArrayObject, attributes, indexBuffer);
    };
    
    /**
     * DOC_TBA.
     *
     * options.source can be {ImageData}, {HTMLImageElement}, {HTMLCanvasElement}, or {HTMLVideoElement}.
     *
     * @memberof Context
     *
     * @returns {Texture} DOC_TBA.
     *
     * @exception {RuntimeError} When options.pixelFormat is DEPTH_COMPONENT or DEPTH_STENCIL, this WebGL implementation must support WEBGL_depth_texture.
     * @exception {RuntimeError} When options.pixelDatatype is FLOAT, this WebGL implementation must support the OES_texture_float extension.
     * @exception {DeveloperError} options requires a source field to create an initialized texture or width and height fields to create a blank texture.
     * @exception {DeveloperError} Width must be greater than zero.
     * @exception {DeveloperError} Width must be less than or equal to the maximum texture size.
     * @exception {DeveloperError} Height must be greater than zero.
     * @exception {DeveloperError} Height must be less than or equal to the maximum texture size.
     * @exception {DeveloperError} Invalid options.pixelFormat.
     * @exception {DeveloperError} Invalid options.pixelDatatype.
     * @exception {DeveloperError} When options.pixelFormat is DEPTH_COMPONENT, options.pixelDatatype must be UNSIGNED_SHORT or UNSIGNED_INT.
     * @exception {DeveloperError} When options.pixelFormat is DEPTH_STENCIL, options.pixelDatatype must be UNSIGNED_INT_24_8_WEBGL.
     * @exception {DeveloperError} When options.pixelFormat is DEPTH_COMPONENT or DEPTH_STENCIL, source cannot be provided.
     *
     * @see Context#createTexture2DFromFramebuffer
     * @see Context#createCubeMap
     * @see Context#createSampler
     *
    Context.prototype.createTexture2D = function(options) {
        options = defaultValue(options, defaultValue.EMPTY_OBJECT);
        
        var source = options.source;
        var width = defined(source) ? source.width : options.width;
        var height = defined(source) ? source.height : options.height;
        var pixelFormat = defaultValue(options.pixelFormat, PixelFormat.RGBA);
        var pixelDatatype = defaultValue(options.pixelDatatype, PixelDatatype.UNSIGNED_BYTE);
        
        //>>includeStart('debug', pragmas.debug);
        if (!defined(width) || !defined(height)) {
            throw new DeveloperError('options requires a source field to create an initialized texture or width and height fields to create a blank texture.');
        }
        
        if (width <= 0) {
            throw new DeveloperError('Width must be greater than zero.');
        }
        
        if (width > this._maximumTextureSize) {
            throw new DeveloperError('Width must be less than or equal to the maximum texture size (' + this._maximumTextureSize + ').  Check maximumTextureSize.');
        }
        
        if (height <= 0) {
            throw new DeveloperError('Height must be greater than zero.');
        }
        
        if (height > this._maximumTextureSize) {
            throw new DeveloperError('Height must be less than or equal to the maximum texture size (' + this._maximumTextureSize + ').  Check maximumTextureSize.');
        }
        
        if (!PixelFormat.validate(pixelFormat)) {
            throw new DeveloperError('Invalid options.pixelFormat.');
        }
        
        if (!PixelDatatype.validate(pixelDatatype)) {
            throw new DeveloperError('Invalid options.pixelDatatype.');
        }
        
        if ((pixelFormat === PixelFormat.DEPTH_COMPONENT) &&
            ((pixelDatatype !== PixelDatatype.UNSIGNED_SHORT) && (pixelDatatype !== PixelDatatype.UNSIGNED_INT))) {
            throw new DeveloperError('When options.pixelFormat is DEPTH_COMPONENT, options.pixelDatatype must be UNSIGNED_SHORT or UNSIGNED_INT.');
        }
        
        if ((pixelFormat === PixelFormat.DEPTH_STENCIL) && (pixelDatatype !== PixelDatatype.UNSIGNED_INT_24_8_WEBGL)) {
            throw new DeveloperError('When options.pixelFormat is DEPTH_STENCIL, options.pixelDatatype must be UNSIGNED_INT_24_8_WEBGL.');
        }
        //>>includeEnd('debug');
        
        if ((pixelDatatype === PixelDatatype.FLOAT) && !this.floatingPointTexture) {
            throw new RuntimeError('When options.pixelDatatype is FLOAT, this WebGL implementation must support the OES_texture_float extension.');
        }
        
        if (PixelFormat.isDepthFormat(pixelFormat)) {
            //>>includeStart('debug', pragmas.debug);
            if (defined(source)) {
                throw new DeveloperError('When options.pixelFormat is DEPTH_COMPONENT or DEPTH_STENCIL, source cannot be provided.');
            }
            //>>includeEnd('debug');
            
            if (!this.depthTexture) {
                throw new RuntimeError('When options.pixelFormat is DEPTH_COMPONENT or DEPTH_STENCIL, this WebGL implementation must support WEBGL_depth_texture.  Check depthTexture.');
            }
        }
        
        // Use premultiplied alpha for opaque textures should perform better on Chrome:
        // http://media.tojicode.com/webglCamp4/#20
        var preMultiplyAlpha = options.preMultiplyAlpha || pixelFormat === PixelFormat.RGB || pixelFormat === PixelFormat.LUMINANCE;
        var flipY = defaultValue(options.flipY, true);
        
        var gl = this._gl;
        var textureTarget = gl.TEXTURE_2D;
        var texture = gl.createTexture();
        
        gl.activeTexture(gl.TEXTURE0);
        gl.bindTexture(textureTarget, texture);
        
        if (defined(source)) {
            // TODO: _gl.pixelStorei(_gl._UNPACK_ALIGNMENT, 4);
            gl.pixelStorei(gl.UNPACK_PREMULTIPLY_ALPHA_WEBGL, preMultiplyAlpha);
            gl.pixelStorei(gl.UNPACK_FLIP_Y_WEBGL, flipY);
            
            if (defined(source.arrayBufferView)) {
                // Source: typed array
                gl.texImage2D(textureTarget, 0, pixelFormat, width, height, 0, pixelFormat, pixelDatatype, source.arrayBufferView);
            } else {
                // Source: ImageData, HTMLImageElement, HTMLCanvasElement, or HTMLVideoElement
                gl.texImage2D(textureTarget, 0, pixelFormat, pixelFormat, pixelDatatype, source);
            }
        } else {
            gl.texImage2D(textureTarget, 0, pixelFormat, width, height, 0, pixelFormat, pixelDatatype, null);
        }
        gl.bindTexture(textureTarget, null);
        
        return new Texture(gl, this._textureFilterAnisotropic, textureTarget, texture, pixelFormat, pixelDatatype, width, height, preMultiplyAlpha, flipY);
    };
    
    /**
     * Creates a texture, and copies a subimage of the framebuffer to it.  When called without arguments,
     * the texture is the same width and height as the framebuffer and contains its contents.
     *
     * @memberof Context
     *
     * @param {PixelFormat} [pixelFormat=PixelFormat.RGB] The texture's internal pixel format.
     * @param {PixelFormat} [framebufferXOffset=0] An offset in the x direction in the framebuffer where copying begins from.
     * @param {PixelFormat} [framebufferYOffset=0] An offset in the y direction in the framebuffer where copying begins from.
     * @param {PixelFormat} [width=canvas.clientWidth] The width of the texture in texels.
     * @param {PixelFormat} [height=canvas.clientHeight] The height of the texture in texels.
     *
     * @returns {Texture} A texture with contents from the framebuffer.
     *
     * @exception {DeveloperError} Invalid pixelFormat.
     * @exception {DeveloperError} pixelFormat cannot be DEPTH_COMPONENT or DEPTH_STENCIL.
     * @exception {DeveloperError} framebufferXOffset must be greater than or equal to zero.
     * @exception {DeveloperError} framebufferYOffset must be greater than or equal to zero.
     * @exception {DeveloperError} framebufferXOffset + width must be less than or equal to canvas.clientWidth.
     * @exception {DeveloperError} framebufferYOffset + height must be less than or equal to canvas.clientHeight.
     *
     * @see Context#createTexture2D
     * @see Context#createCubeMap
     * @see Context#createSampler
     *
     * @example
     * // Create a texture with the contents of the framebuffer.
     * var t = context.createTexture2DFromFramebuffer();
     *
    Context.prototype.createTexture2DFromFramebuffer = function(pixelFormat, framebufferXOffset, framebufferYOffset, width, height) {
        var gl = this._gl;
        
        pixelFormat = defaultValue(pixelFormat, PixelFormat.RGB);
        framebufferXOffset = defaultValue(framebufferXOffset, 0);
        framebufferYOffset = defaultValue(framebufferYOffset, 0);
        width = defaultValue(width, gl.drawingBufferWidth);
        height = defaultValue(height, gl.drawingBufferHeight);
        
        //>>includeStart('debug', pragmas.debug);
        if (!PixelFormat.validate(pixelFormat)) {
            throw new DeveloperError('Invalid pixelFormat.');
        }
        
        if (PixelFormat.isDepthFormat(pixelFormat)) {
            throw new DeveloperError('pixelFormat cannot be DEPTH_COMPONENT or DEPTH_STENCIL.');
        }
        
        if (framebufferXOffset < 0) {
            throw new DeveloperError('framebufferXOffset must be greater than or equal to zero.');
        }
        
        if (framebufferYOffset < 0) {
            throw new DeveloperError('framebufferYOffset must be greater than or equal to zero.');
        }
        
        if (framebufferXOffset + width > gl.drawingBufferWidth) {
            throw new DeveloperError('framebufferXOffset + width must be less than or equal to drawingBufferWidth');
        }
        
        if (framebufferYOffset + height > gl.drawingBufferHeight) {
            throw new DeveloperError('framebufferYOffset + height must be less than or equal to drawingBufferHeight.');
        }
        //>>includeEnd('debug');
        
        var textureTarget = gl.TEXTURE_2D;
        var texture = gl.createTexture();
        
        gl.activeTexture(gl.TEXTURE0);
        gl.bindTexture(textureTarget, texture);
        gl.copyTexImage2D(textureTarget, 0, pixelFormat, framebufferXOffset, framebufferYOffset, width, height, 0);
        gl.bindTexture(textureTarget, null);
        
        return new Texture(gl, this._textureFilterAnisotropic, textureTarget, texture, pixelFormat, undefined, width, height);
    };
    
    /**
     * Creates a new texture atlas with this context.
     *
     * @memberof Context
     *
     * @param {PixelFormat} [options.pixelFormat = PixelFormat.RGBA] The pixel format of the texture.
     * @param {Number} [options.borderWidthInPixels = 1] The amount of spacing between adjacent images in pixels.
     * @param {Cartesian2} [options.initialSize = new Cartesian2(16.0, 16.0)] The initial side lengths of the texture.
     * @param {Array} [options.images=undefined] Array of {@link Image} to be added to the atlas. Same as calling addImages(images).
     * @param {Image} [options.image=undefined] Single image to be added to the atlas. Same as calling addImage(image).
     *
     * @returns {TextureAtlas} The new texture atlas.
     *
     * @see TextureAtlas
     *
    Context.prototype.createTextureAtlas = function(options) {
        options = defaultValue(options, {});
        options.context = this;
        return new TextureAtlas(options);
    };
    
    /**
     * DOC_TBA.
     *
     * options.source can be {ImageData}, {HTMLImageElement}, {HTMLCanvasElement}, or {HTMLVideoElement}.
     *
     * @memberof Context
     *
     * @returns {CubeMap} DOC_TBA.
     *
     * @exception {RuntimeError} When options.pixelDatatype is FLOAT, this WebGL implementation must support the OES_texture_float extension.
     * @exception {DeveloperError} options.source requires positiveX, negativeX, positiveY, negativeY, positiveZ, and negativeZ faces.
     * @exception {DeveloperError} Each face in options.sources must have the same width and height.
     * @exception {DeveloperError} options requires a source field to create an initialized cube map or width and height fields to create a blank cube map.
     * @exception {DeveloperError} Width must equal height.
     * @exception {DeveloperError} Width and height must be greater than zero.
     * @exception {DeveloperError} Width and height must be less than or equal to the maximum cube map size.
     * @exception {DeveloperError} Invalid options.pixelFormat.
     * @exception {DeveloperError} options.pixelFormat cannot be DEPTH_COMPONENT or DEPTH_STENCIL.
     * @exception {DeveloperError} Invalid options.pixelDatatype.
     *
     * @see Context#createTexture2D
     * @see Context#createTexture2DFromFramebuffer
     * @see Context#createSampler
     *
    Context.prototype.createCubeMap = function(options) {
        options = defaultValue(options, defaultValue.EMPTY_OBJECT);
        
        var source = options.source;
        var width;
        var height;
        
        if (defined(source)) {
            var faces = [source.positiveX, source.negativeX, source.positiveY, source.negativeY, source.positiveZ, source.negativeZ];
            
            //>>includeStart('debug', pragmas.debug);
            if (!faces[0] || !faces[1] || !faces[2] || !faces[3] || !faces[4] || !faces[5]) {
                throw new DeveloperError('options.source requires positiveX, negativeX, positiveY, negativeY, positiveZ, and negativeZ faces.');
            }
            //>>includeEnd('debug');
            
            width = faces[0].width;
            height = faces[0].height;
            
            //>>includeStart('debug', pragmas.debug);
            for ( var i = 1; i < 6; ++i) {
                if ((Number(faces[i].width) !== width) || (Number(faces[i].height) !== height)) {
                    throw new DeveloperError('Each face in options.source must have the same width and height.');
                }
            }
            //>>includeEnd('debug');
        } else {
            width = options.width;
            height = options.height;
        }
        
        var size = width;
        var pixelFormat = defaultValue(options.pixelFormat, PixelFormat.RGBA);
        var pixelDatatype = defaultValue(options.pixelDatatype, PixelDatatype.UNSIGNED_BYTE);
        
        //>>includeStart('debug', pragmas.debug);
        if (!defined(width) || !defined(height)) {
            throw new DeveloperError('options requires a source field to create an initialized cube map or width and height fields to create a blank cube map.');
        }
        
        if (width !== height) {
            throw new DeveloperError('Width must equal height.');
        }
        
        if (size <= 0) {
            throw new DeveloperError('Width and height must be greater than zero.');
        }
        
        if (size > this._maximumCubeMapSize) {
            throw new DeveloperError('Width and height must be less than or equal to the maximum cube map size (' + this._maximumCubeMapSize + ').  Check maximumCubeMapSize.');
        }
        
        if (!PixelFormat.validate(pixelFormat)) {
            throw new DeveloperError('Invalid options.pixelFormat.');
        }
        
        if (PixelFormat.isDepthFormat(pixelFormat)) {
            throw new DeveloperError('options.pixelFormat cannot be DEPTH_COMPONENT or DEPTH_STENCIL.');
        }
        
        if (!PixelDatatype.validate(pixelDatatype)) {
            throw new DeveloperError('Invalid options.pixelDatatype.');
        }
        //>>includeEnd('debug');
        
        if ((pixelDatatype === PixelDatatype.FLOAT) && !this.floatingPointTexture) {
            throw new RuntimeError('When options.pixelDatatype is FLOAT, this WebGL implementation must support the OES_texture_float extension.');
        }
        
        // Use premultiplied alpha for opaque textures should perform better on Chrome:
        // http://media.tojicode.com/webglCamp4/#20
        var preMultiplyAlpha = options.preMultiplyAlpha || ((pixelFormat === PixelFormat.RGB) || (pixelFormat === PixelFormat.LUMINANCE));
        var flipY = defaultValue(options.flipY, true);
        
        var gl = this._gl;
        var textureTarget = gl.TEXTURE_CUBE_MAP;
        var texture = gl.createTexture();
        
        gl.activeTexture(gl.TEXTURE0);
        gl.bindTexture(textureTarget, texture);
        
        function createFace(target, sourceFace) {
            if (sourceFace.arrayBufferView) {
                gl.texImage2D(target, 0, pixelFormat, size, size, 0, pixelFormat, pixelDatatype, sourceFace.arrayBufferView);
            } else {
                gl.texImage2D(target, 0, pixelFormat, pixelFormat, pixelDatatype, sourceFace);
            }
        }
        
        if (defined(source)) {
            // TODO: _gl.pixelStorei(_gl._UNPACK_ALIGNMENT, 4);
            gl.pixelStorei(gl.UNPACK_PREMULTIPLY_ALPHA_WEBGL, preMultiplyAlpha);
            gl.pixelStorei(gl.UNPACK_FLIP_Y_WEBGL, flipY);
            
            createFace(gl.TEXTURE_CUBE_MAP_POSITIVE_X, source.positiveX);
            createFace(gl.TEXTURE_CUBE_MAP_NEGATIVE_X, source.negativeX);
            createFace(gl.TEXTURE_CUBE_MAP_POSITIVE_Y, source.positiveY);
            createFace(gl.TEXTURE_CUBE_MAP_NEGATIVE_Y, source.negativeY);
            createFace(gl.TEXTURE_CUBE_MAP_POSITIVE_Z, source.positiveZ);
            createFace(gl.TEXTURE_CUBE_MAP_NEGATIVE_Z, source.negativeZ);
        } else {
            gl.texImage2D(gl.TEXTURE_CUBE_MAP_POSITIVE_X, 0, pixelFormat, size, size, 0, pixelFormat, pixelDatatype, null);
            gl.texImage2D(gl.TEXTURE_CUBE_MAP_NEGATIVE_X, 0, pixelFormat, size, size, 0, pixelFormat, pixelDatatype, null);
            gl.texImage2D(gl.TEXTURE_CUBE_MAP_POSITIVE_Y, 0, pixelFormat, size, size, 0, pixelFormat, pixelDatatype, null);
            gl.texImage2D(gl.TEXTURE_CUBE_MAP_NEGATIVE_Y, 0, pixelFormat, size, size, 0, pixelFormat, pixelDatatype, null);
            gl.texImage2D(gl.TEXTURE_CUBE_MAP_POSITIVE_Z, 0, pixelFormat, size, size, 0, pixelFormat, pixelDatatype, null);
            gl.texImage2D(gl.TEXTURE_CUBE_MAP_NEGATIVE_Z, 0, pixelFormat, size, size, 0, pixelFormat, pixelDatatype, null);
        }
        gl.bindTexture(textureTarget, null);
        
        return new CubeMap(gl, this._textureFilterAnisotropic, textureTarget, texture, pixelFormat, pixelDatatype, size, preMultiplyAlpha, flipY);
    };
    
    /**
     * Creates a framebuffer with optional initial color, depth, and stencil attachments.
     * Framebuffers are used for render-to-texture effects; they allow us to render to
     * textures in one pass, and read from it in a later pass.
     *
     * @memberof Context
     *
     * @param {Object} [options] The initial framebuffer attachments as shown in the examplebelow.  The possible properties are <code>colorTextures</code>, <code>colorRenderbuffers</code>, <code>depthTexture</code>, <code>depthRenderbuffer</code>, <code>stencilRenderbuffer</code>, <code>depthStencilTexture</code>, and <code>depthStencilRenderbuffer</code>.
     *
     * @returns {Framebuffer} The created framebuffer.
     *
     * @exception {DeveloperError} Cannot have both color texture and color renderbuffer attachments.
     * @exception {DeveloperError} Cannot have both a depth texture and depth renderbuffer attachment.
     * @exception {DeveloperError} Cannot have both a depth-stencil texture and depth-stencil renderbuffer attachment.
     * @exception {DeveloperError} Cannot have both a depth and depth-stencil renderbuffer.
     * @exception {DeveloperError} Cannot have both a stencil and depth-stencil renderbuffer.
     * @exception {DeveloperError} Cannot have both a depth and stencil renderbuffer.
     * @exception {DeveloperError} The color-texture pixel-format must be a color format.
     * @exception {DeveloperError} The depth-texture pixel-format must be DEPTH_COMPONENT.
     * @exception {DeveloperError} The depth-stencil-texture pixel-format must be DEPTH_STENCIL.
     * @exception {DeveloperError} The number of color attachments exceeds the number supported.
     *
     * @see Context#createTexture2D
     * @see Context#createCubeMap
     * @see Context#createRenderbuffer
     *
     * @example
     * // Create a framebuffer with color and depth texture attachments.
     * var width = context.canvas.clientWidth;
     * var height = context.canvas.clientHeight;
     * var framebuffer = context.createFramebuffer({
     *   colorTextures : [context.createTexture2D({
     *     width : width,
     *     height : height,
     *     pixelFormat : PixelFormat.RGBA
     *   })],
     *   depthTexture : context.createTexture2D({
     *     width : width,
     *     height : height,
     *     pixelFormat : PixelFormat.DEPTH_COMPONENT,
     *     pixelDatatype : PixelDatatype.UNSIGNED_SHORT
     *   })
     * });
     *
    Context.prototype.createFramebuffer = function(options) {
        return new Framebuffer(this._gl, this._maximumColorAttachments, options);
    };
    
    /**
     * DOC_TBA.
     *
     * @memberof Context
     *
     * @param {Object} [options] DOC_TBA.
     *
     * @returns {createRenderbuffer} DOC_TBA.
     *
     * @exception {DeveloperError} Invalid format.
     * @exception {DeveloperError} Width must be greater than zero.
     * @exception {DeveloperError} Width must be less than or equal to the maximum renderbuffer size.
     * @exception {DeveloperError} Height must be greater than zero.
     * @exception {DeveloperError} Height must be less than or equal to the maximum renderbuffer size.
     *
     * @se Context#createFramebuffer
     *
    Context.prototype.createRenderbuffer = function(options) {
        var gl = this._gl;
        
        options = defaultValue(options, defaultValue.EMPTY_OBJECT);
        var format = defaultValue(options.format, RenderbufferFormat.RGBA4);
        var width = defined(options.width) ? options.width : gl.drawingBufferWidth;
        var height = defined(options.height) ? options.height : gl.drawingBufferHeight;
        
        //>>includeStart('debug', pragmas.debug);
        if (!RenderbufferFormat.validate(format)) {
            throw new DeveloperError('Invalid format.');
        }
        
        if (width <= 0) {
            throw new DeveloperError('Width must be greater than zero.');
        }
        
        if (width > this.maximumRenderbufferSize) {
            throw new DeveloperError('Width must be less than or equal to the maximum renderbuffer size (' + this.maximumRenderbufferSize + ').  Check maximumRenderbufferSize.');
        }
        
        if (height <= 0) {
            throw new DeveloperError('Height must be greater than zero.');
        }
        
        if (height > this.maximumRenderbufferSize) {
            throw new DeveloperError('Height must be less than or equal to the maximum renderbuffer size (' + this.maximumRenderbufferSize + ').  Check maximumRenderbufferSize.');
        }
        //>>includeEnd('debug');
        
        return new Renderbuffer(gl, format, width, height);
    };
    
    var nextRenderStateId = 0;
    var renderStateCache = {};
    
    /**
     * Validates and then finds or creates an immutable render state, which defines the pipeline
     * state for a {@link DrawCommand} or {@link ClearCommand}.  All inputs states are optional.  Omitted states
     * use the defaults shown in the example below.
     *
     * @memberof Context
     *
     * @param {Object} [renderState=undefined] The states defining the render state as shown in the example below.
     *
     * @exception {RuntimeError} renderState.lineWidth is out of range.
     * @exception {DeveloperError} Invalid renderState.frontFace.
     * @exception {DeveloperError} Invalid renderState.cull.face.
     * @exception {DeveloperError} scissorTest.rectangle.width and scissorTest.rectangle.height must be greater than or equal to zero.
     * @exception {DeveloperError} renderState.depthRange.near can't be greater than renderState.depthRange.far.
     * @exception {DeveloperError} renderState.depthRange.near must be greater than or equal to zero.
     * @exception {DeveloperError} renderState.depthRange.far must be less than or equal to zero.
     * @exception {DeveloperError} Invalid renderState.depthTest.func.
     * @exception {DeveloperError} renderState.blending.color components must be greater than or equal to zero and less than or equal to one
     * @exception {DeveloperError} Invalid renderState.blending.equationRgb.
     * @exception {DeveloperError} Invalid renderState.blending.equationAlpha.
     * @exception {DeveloperError} Invalid renderState.blending.functionSourceRgb.
     * @exception {DeveloperError} Invalid renderState.blending.functionSourceAlpha.
     * @exception {DeveloperError} Invalid renderState.blending.functionDestinationRgb.
     * @exception {DeveloperError} Invalid renderState.blending.functionDestinationAlpha.
     * @exception {DeveloperError} Invalid renderState.stencilTest.frontFunction.
     * @exception {DeveloperError} Invalid renderState.stencilTest.backFunction.
     * @exception {DeveloperError} Invalid renderState.stencilTest.frontOperation.fail.
     * @exception {DeveloperError} Invalid renderState.stencilTest.frontOperation.zFail.
     * @exception {DeveloperError} Invalid renderState.stencilTest.frontOperation.zPass.
     * @exception {DeveloperError} Invalid renderState.stencilTest.backOperation.fail.
     * @exception {DeveloperError} Invalid renderState.stencilTest.backOperation.zFail.
     * @exception {DeveloperError} Invalid renderState.stencilTest.backOperation.zPass.
     * @exception {DeveloperError} renderState.viewport.width must be greater than or equal to zero.
     * @exception {DeveloperError} renderState.viewport.width must be less than or equal to the maximum viewport width.
     * @exception {DeveloperError} renderState.viewport.height must be greater than or equal to zero.
     * @exception {DeveloperError} renderState.viewport.height must be less than or equal to the maximum viewport height.
     *
     * @example
     * var defaults = {
     *     frontFace : WindingOrder.COUNTER_CLOCKWISE,
     *     cull : {
     *         enabled : false,
     *         face : CullFace.BACK
     *     },
     *     lineWidth : 1,
     *     polygonOffset : {
     *         enabled : false,
     *         factor : 0,
     *         units : 0
     *     },
     *     scissorTest : {
     *         enabled : false,
     *         rectangle : {
     *             x : 0,
     *             y : 0,
     *             width : 0,
     *             height : 0
     *         }
     *     },
     *     depthRange : {
     *         near : 0,
     *         far : 1
     *     },
     *     depthTest : {
     *         enabled : false,
     *         func : DepthFunction.LESS
     *      },
     *     colorMask : {
     *         red : true,
     *         green : true,
     *         blue : true,
     *         alpha : true
     *     },
     *     depthMask : true,
     *     stencilMask : ~0,
     *     blending : {
     *         enabled : false,
     *         color : {
     *             red : 0.0,
     *             green : 0.0,
     *             blue : 0.0,
     *             alpha : 0.0
     *         },
     *         equationRgb : BlendEquation.ADD,
     *         equationAlpha : BlendEquation.ADD,
     *         functionSourceRgb : BlendFunction.ONE,
     *         functionSourceAlpha : BlendFunction.ONE,
     *         functionDestinationRgb : BlendFunction.ZERO,
     *         functionDestinationAlpha : BlendFunction.ZERO
     *     },
     *     stencilTest : {
     *         enabled : false,
     *         frontFunction : StencilFunction.ALWAYS,
     *         backFunction : StencilFunction.ALWAYS,
     *         reference : 0,
     *         mask : ~0,
     *         frontOperation : {
     *             fail : StencilOperation.KEEP,
     *             zFail : StencilOperation.KEEP,
     *             zPass : StencilOperation.KEEP
     *         },
     *         backOperation : {
     *             fail : StencilOperation.KEEP,
     *             zFail : StencilOperation.KEEP,
     *             zPass : StencilOperation.KEEP
     *         }
     *     },
     *     sampleCoverage : {
     *         enabled : false,
     *         value : 1.0,
     *         invert : false
     *      },
     *     dither : true
     * };
     *
     * // Same as just context.createRenderState().
     * var rs = context.createRenderState(defaults);
     *
     * @see DrawCommand
     * @see ClearCommand
     */
-(CSRenderState *)createRenderState
{
    return [[CSRenderState alloc] init];
}/*
    Context.prototype.createRenderState = function(renderState) {
        var partialKey = JSON.stringify(renderState);
        var cachedState = renderStateCache[partialKey];
        if (defined(cachedState)) {
            return cachedState;
        }
        
        // Cache miss.  Fully define render state and try again.
        var states = new RenderState(this, renderState);
        var fullKey = JSON.stringify(states);
        cachedState = renderStateCache[fullKey];
        if (!defined(cachedState)) {
            states.id = nextRenderStateId++;
            
            cachedState = states;
            
            // Cache full render state.  Multiple partially defined render states may map to this.
            renderStateCache[fullKey] = cachedState;
        }
        
        // Cache partial render state so we can skip validation on a cache hit for a partially defined render state
        renderStateCache[partialKey] = cachedState;
        
        return cachedState;
    };
    
    /**
     * DOC_TBA
     *
     * @memberof Context
     *
     * @exception {DeveloperError} Invalid sampler.wrapS.
     * @exception {DeveloperError} Invalid sampler.wrapT.
     * @exception {DeveloperError} Invalid sampler.minificationFilter.
     * @exception {DeveloperError} Invalid sampler.magnificationFilter.
     *
     * @see Context#createTexture2D
     * @see Context#reateCubeMap
     *
    Context.prototype.createSampler = function(sampler) {
        var s = {
            wrapS : defaultValue(sampler.wrapS, TextureWrap.CLAMP_TO_EDGE),
            wrapT : defaultValue(sampler.wrapT, TextureWrap.CLAMP_TO_EDGE),
            minificationFilter : defaultValue(sampler.minificationFilter, TextureMinificationFilter.LINEAR),
            magnificationFilter : defaultValue(sampler.magnificationFilter, TextureMagnificationFilter.LINEAR),
            maximumAnisotropy : (defined(sampler.maximumAnisotropy)) ? sampler.maximumAnisotropy : 1.0
        };
        
        //>>includeStart('debug', pragmas.debug);
        if (!TextureWrap.validate(s.wrapS)) {
            throw new DeveloperError('Invalid sampler.wrapS.');
        }
        
        if (!TextureWrap.validate(s.wrapT)) {
            throw new DeveloperError('Invalid sampler.wrapT.');
        }
        
        if (!TextureMinificationFilter.validate(s.minificationFilter)) {
            throw new DeveloperError('Invalid sampler.minificationFilter.');
        }
        
        if (!TextureMagnificationFilter.validate(s.magnificationFilter)) {
            throw new DeveloperError('Invalid sampler.magnificationFilter.');
        }
        
        if (s.maximumAnisotropy < 1.0) {
            throw new DeveloperError('sampler.maximumAnisotropy must be greater than or equal to one.');
        }
        //>>includeEnd('debug');
        
        return s;
    };
    
    function validateFramebuffer(context, framebuffer) {
        if (context.validateFramebuffer) {
            var gl = context._gl;
            var status = gl.checkFramebufferStatus(gl.FRAMEBUFFER);
            
            if (status !== gl.FRAMEBUFFER_COMPLETE) {
                var message;
                
                switch (status) {
                    case gl.FRAMEBUFFER_INCOMPLETE_ATTACHMENT:
                        message = 'Framebuffer is not complete.  Incomplete attachment: at least one attachment point with a renderbuffer or texture attached has its attached object no longer in existence or has an attached image with a width or height of zero, or the color attachment point has a non-color-renderable image attached, or the depth attachment point has a non-depth-renderable image attached, or the stencil attachment point has a non-stencil-renderable image attached.  Color-renderable formats include GL_RGBA4, GL_RGB5_A1, and GL_RGB565. GL_DEPTH_COMPONENT16 is the only depth-renderable format. GL_STENCIL_INDEX8 is the only stencil-renderable format.';
                        break;
                    case gl.FRAMEBUFFER_INCOMPLETE_DIMENSIONS:
                        message = 'Framebuffer is not complete.  Incomplete dimensions: not all attached images have the same width and height.';
                        break;
                    case gl.FRAMEBUFFER_INCOMPLETE_MISSING_ATTACHMENT:
                        message = 'Framebuffer is not complete.  Missing attachment: no images are attached to the framebuffer.';
                        break;
                    case gl.FRAMEBUFFER_UNSUPPORTED:
                        message = 'Framebuffer is not complete.  Unsupported: the combination of internal formats of the attached images violates an implementation-dependent set of restrictions.';
                        break;
                }
                
                throw new DeveloperError(message);
            }
        }
    }
    
    function applyRenderState(context, renderState, passState) {
        var previousState = context._currentRenderState;
        if (previousState !== renderState) {
            context._currentRenderState = renderState;
            RenderState.partialApply(context._gl, previousState, renderState, passState);
        }
        // else same render state as before so state is already applied.
    }
    
    var scratchBackBufferArray;
    // this check must use typeof, not defined, because defined doesn't work with undeclared variables.
    if (typeof WebGLRenderingContext !== 'undefined') {
        scratchBackBufferArray = [WebGLRenderingContext.BACK];
    }
    
    function bindFramebuffer(context, framebuffer) {
        if (framebuffer !== context._currentFramebuffer) {
            context._currentFramebuffer = framebuffer;
            var buffers = scratchBackBufferArray;
            
            if (defined(framebuffer)) {
                framebuffer._bind();
                validateFramebuffer(context, framebuffer);
                
                // TODO: Need a way for a command to give what draw buffers are active.
                buffers = framebuffer._getActiveColorAttachments();
            } else {
                var gl = context._gl;
                gl.bindFramebuffer(gl.FRAMEBUFFER, null);
            }
            
            if (context.drawBuffers) {
                context._drawBuffers.drawBuffersWEBGL(buffers);
            }
        }
    }
    
    var defaultClearCommand = new ClearCommand();
    
    /**
     * Executes the specified clear command.
     *
     * @memberof Context
     *
     * @param {ClearCommand} [clearCommand] The command with which to clear.
     * @param {PassState} [passState] The state for the current rendering pass.
     *
     * @memberof Context
     *
     * @see ClearCommand
     *
    Context.prototype.clear = function(clearCommand, passState) {
        clearCommand = defaultValue(clearCommand, defaultClearCommand);
        passState = defaultValue(passState, this._defaultPassState);
        
        var gl = this._gl;
        var bitmask = 0;
        
        var c = clearCommand.color;
        var d = clearCommand.depth;
        var s = clearCommand.stencil;
        
        if (defined(c)) {
            if (!Color.equals(this._clearColor, c)) {
                Color.clone(c, this._clearColor);
                gl.clearColor(c.red, c.green, c.blue, c.alpha);
            }
            bitmask |= gl.COLOR_BUFFER_BIT;
        }
        
        if (defined(d)) {
            if (d !== this._clearDepth) {
                this._clearDepth = d;
                gl.clearDepth(d);
            }
            bitmask |= gl.DEPTH_BUFFER_BIT;
        }
        
        if (defined(s)) {
            if (s !== this._clearStencil) {
                this._clearStencil = s;
                gl.clearStencil(s);
            }
            bitmask |= gl.STENCIL_BUFFER_BIT;
        }
        
        var rs = defaultValue(clearCommand.renderState, this._defaultRenderState);
        applyRenderState(this, rs, passState);
        
        // The command's framebuffer takes presidence over the pass' framebuffer, e.g., for off-screen rendering.
        var framebuffer = defaultValue(clearCommand.framebuffer, passState.framebuffer);
        bindFramebuffer(this, framebuffer);
        
        gl.clear(bitmask);
    };
    
    function beginDraw(context, framebuffer, drawCommand, passState, renderState, shaderProgram) {
        var rs = defaultValue(defaultValue(renderState, drawCommand.renderState), context._defaultRenderState);
        
        //>>includeStart('debug', pragmas.debug);
        if (defined(framebuffer) && rs.depthTest) {
            if (rs.depthTest.enabled && !framebuffer.hasDepthAttachment) {
                throw new DeveloperError('The depth test can not be enabled (drawCommand.renderState.depthTest.enabled) because the framebuffer (drawCommand.framebuffer) does not have a depth or depth-stencil renderbuffer.');
            }
        }
        //>>includeEnd('debug');
        
        bindFramebuffer(context, framebuffer);
        
        var sp = defaultValue(shaderProgram, drawCommand.shaderProgram);
        sp._bind();
        context._maxFrameTextureUnitIndex = Math.max(context._maxFrameTextureUnitIndex, sp.maximumTextureUnitIndex);
        
        applyRenderState(context, rs, passState);
    }
    
    function continueDraw(context, drawCommand, shaderProgram) {
        var primitiveType = drawCommand.primitiveType;
        var va = drawCommand.vertexArray;
        var offset = drawCommand.offset;
        var count = drawCommand.count;
        
        //>>includeStart('debug', pragmas.debug);
        if (!PrimitiveType.validate(primitiveType)) {
            throw new DeveloperError('drawCommand.primitiveType is required and must be valid.');
        }
        
        if (!defined(va)) {
            throw new DeveloperError('drawCommand.vertexArray is required.');
        }
        
        if (offset < 0) {
            throw new DeveloperError('drawCommand.offset must be omitted or greater than or equal to zero.');
        }
        
        if (count < 0) {
            throw new DeveloperError('drawCommand.count must be omitted or greater than or equal to zero.');
        }
        //>>includeEnd('debug');
        
        context._us.model = defaultValue(drawCommand.modelMatrix, Matrix4.IDENTITY);
        var sp = defaultValue(shaderProgram, drawCommand.shaderProgram);
        sp._setUniforms(drawCommand.uniformMap, context._us, context.validateShaderProgram);
        
        var indexBuffer = va.indexBuffer;
        
        if (defined(indexBuffer)) {
            offset = offset * indexBuffer.bytesPerIndex; // offset in vertices to offset in bytes
            count = defaultValue(count, indexBuffer.numberOfIndices);
            
            va._bind();
            context._gl.drawElements(primitiveType, count, indexBuffer.indexDatatype, offset);
            va._unBind();
        } else {
            count = defaultValue(count, va.numberOfVertices);
            
            va._bind();
            context._gl.drawArrays(primitiveType, offset, count);
            va._unBind();
        }
    }
    
    /**
     * Executes the specified draw command.
     *
     * @memberof Context
     *
     * @param {DrawCommand} drawCommand The command with which to draw.
     * @param {PassState} [passState] The state for the current rendering pass.
     * @param {RenderState} [renderState] The render state that will override the render state of the command.
     * @param {ShaderProgram} [shaderProgram] The shader program that will override the shader program of the command.
     *
     * @memberof Context
     *
     * @exception {DeveloperError} drawCommand.offset must be omitted or greater than or equal to zero.
     * @exception {DeveloperError} drawCommand.count must be omitted or greater than or equal to zero.
     * @exception {DeveloperError} Program validation failed.
     * @exception {DeveloperError} Framebuffer is not complete.
     *
     * @example
     * // Example 1.  Draw a single triangle specifying only required arguments
     * context.draw({
     *     primitiveType : PrimitiveType.TRIANGLES,
     *     shaderProgram : sp,
     *     vertexArray   : va,
     * });
     *
     * ////////////////////////////////////////////////////////////////////////////////
     *
     * // Example 2.  Draw a single triangle specifying every argument
     * context.draw({
     *     primitiveType : PrimitiveType.TRIANGLES,
     *     offset        : 0,
     *     count         : 3,
     *     framebuffer   : fb,
     *     shaderProgram : sp,
     *     vertexArray   : va,
     *     renderState   : rs
     * });
     *
     * @see Context#createShaderProgram
     * @see Context#createVertexArray
     * @see Context#createFramebuffer
     * @see Context#createRenderState
     *
    Context.prototype.draw = function(drawCommand, passState, renderState, shaderProgram) {
        //>>includeStart('debug', pragmas.debug);
        if (!defined(drawCommand)) {
            throw new DeveloperError('drawCommand is required.');
        }
        
        if (!defined(drawCommand.shaderProgram)) {
            throw new DeveloperError('drawCommand.shaderProgram is required.');
        }
        //>>includeEnd('debug');
        
        passState = defaultValue(passState, this._defaultPassState);
        // The command's framebuffer takes presidence over the pass' framebuffer, e.g., for off-screen rendering.
        var framebuffer = defaultValue(drawCommand.framebuffer, passState.framebuffer);
        
        beginDraw(this, framebuffer, drawCommand, passState, renderState, shaderProgram);
        continueDraw(this, drawCommand, shaderProgram);
    };
    
    /**
     * @private
     *
    Context.prototype.endFrame = function() {
        var gl = this._gl;
        gl.useProgram(null);
        
        this._currentFramebuffer = undefined;
        gl.bindFramebuffer(gl.FRAMEBUFFER, null);
        
        var buffers = scratchBackBufferArray;
        if (this.drawBuffers) {
            this._drawBuffers.drawBuffersWEBGL(scratchBackBufferArray);
        }
        
        var length = this._maxFrameTextureUnitIndex;
        this._maxFrameTextureUnitIndex = 0;
        
        for (var i = 0; i < length; ++i) {
            gl.activeTexture(gl.TEXTURE0 + i);
            gl.bindTexture(gl.TEXTURE_2D, null);
            gl.bindTexture(gl.TEXTURE_CUBE_MAP, null);
        }
    };
    
    /**
     * DOC_TBA
     *
     * @memberof Context
     *
     * @exception {DeveloperError} readState.width must be greater than zero.
     * @exception {DeveloperError} readState.height must be greater than zero.
     *
    Context.prototype.readPixels = function(readState) {
        var gl = this._gl;
        
        readState = readState || {};
        var x = Math.max(readState.x || 0, 0);
        var y = Math.max(readState.y || 0, 0);
        var width = readState.width || gl.drawingBufferWidth;
        var height = readState.height || gl.drawingBufferHeight;
        var framebuffer = readState.framebuffer;
        
        //>>includeStart('debug', pragmas.debug);
        if (width <= 0) {
            throw new DeveloperError('readState.width must be greater than zero.');
        }
        
        if (height <= 0) {
            throw new DeveloperError('readState.height must be greater than zero.');
        }
        //>>includeEnd('debug');
        
        var pixels = new Uint8Array(4 * width * height);
        
        bindFramebuffer(this, framebuffer);
        
        gl.readPixels(x, y, width, height, gl.RGBA, gl.UNSIGNED_BYTE, pixels);
        
        return pixels;
    };
    
    //////////////////////////////////////////////////////////////////////////////////////////
    
    function computeNumberOfVertices(attribute) {
        return attribute.values.length / attribute.componentsPerAttribute;
    }
    
    function computeAttributeSizeInBytes(attribute) {
        return attribute.componentDatatype.sizeInBytes * attribute.componentsPerAttribute;
    }
    
    function interleaveAttributes(attributes) {
        var j;
        var name;
        var attribute;
        
        // Extract attribute names.
        var names = [];
        for (name in attributes) {
            // Attribute needs to have per-vertex values; not a constant value for all vertices.
            if (attributes.hasOwnProperty(name) &&
                defined(attributes[name]) &&
                defined(attributes[name].values)) {
                names.push(name);
                
                if (attributes[name].componentDatatype.value === ComponentDatatype.DOUBLE.value) {
                    attributes[name].componentDatatype = ComponentDatatype.FLOAT;
                    attributes[name].values = ComponentDatatype.createTypedArray(ComponentDatatype.FLOAT, attributes[name].values);
                }
            }
        }
        
        // Validation.  Compute number of vertices.
        var numberOfVertices;
        var namesLength = names.length;
        
        if (namesLength > 0) {
            numberOfVertices = computeNumberOfVertices(attributes[names[0]]);
            
            for (j = 1; j < namesLength; ++j) {
                var currentNumberOfVertices = computeNumberOfVertices(attributes[names[j]]);
                
                if (currentNumberOfVertices !== numberOfVertices) {
                    throw new RuntimeError(
                                           'Each attribute list must have the same number of vertices.  ' +
                                           'Attribute ' + names[j] + ' has a different number of vertices ' +
                                           '(' + currentNumberOfVertices.toString() + ')' +
                                           ' than attribute ' + names[0] +
                                           ' (' + numberOfVertices.toString() + ').');
                }
            }
        }
        
        // Sort attributes by the size of their components.  From left to right, a vertex stores floats, shorts, and then bytes.
        names.sort(function(left, right) {
            return attributes[right].componentDatatype.sizeInBytes - attributes[left].componentDatatype.sizeInBytes;
        });
        
        // Compute sizes and strides.
        var vertexSizeInBytes = 0;
        var offsetsInBytes = {};
        
        for (j = 0; j < namesLength; ++j) {
            name = names[j];
            attribute = attributes[name];
            
            offsetsInBytes[name] = vertexSizeInBytes;
            vertexSizeInBytes += computeAttributeSizeInBytes(attribute);
        }
        
        if (vertexSizeInBytes > 0) {
            // Pad each vertex to be a multiple of the largest component datatype so each
            // attribute can be addressed using typed arrays.
            var maxComponentSizeInBytes = attributes[names[0]].componentDatatype.sizeInBytes; // Sorted large to small
            var remainder = vertexSizeInBytes % maxComponentSizeInBytes;
            if (remainder !== 0) {
                vertexSizeInBytes += (maxComponentSizeInBytes - remainder);
            }
            
            // Total vertex buffer size in bytes, including per-vertex padding.
            var vertexBufferSizeInBytes = numberOfVertices * vertexSizeInBytes;
            
            // Create array for interleaved vertices.  Each attribute has a different view (pointer) into the array.
            var buffer = new ArrayBuffer(vertexBufferSizeInBytes);
            var views = {};
            
            for (j = 0; j < namesLength; ++j) {
                name = names[j];
                var sizeInBytes = attributes[name].componentDatatype.sizeInBytes;
                
                views[name] = {
                    pointer : ComponentDatatype.createTypedArray(attributes[name].componentDatatype, buffer),
                    index : offsetsInBytes[name] / sizeInBytes, // Offset in ComponentType
                    strideInComponentType : vertexSizeInBytes / sizeInBytes
                };
            }
            
            // Copy attributes into one interleaved array.
            // PERFORMANCE_IDEA:  Can we optimize these loops?
            for (j = 0; j < numberOfVertices; ++j) {
                for ( var n = 0; n < namesLength; ++n) {
                    name = names[n];
                    attribute = attributes[name];
                    var values = attribute.values;
                    var view = views[name];
                    var pointer = view.pointer;
                    
                    var numberOfComponents = attribute.componentsPerAttribute;
                    for ( var k = 0; k < numberOfComponents; ++k) {
                        pointer[view.index + k] = values[(j * numberOfComponents) + k];
                    }
                    
                    view.index += view.strideInComponentType;
                }
            }
            
            return {
                buffer : buffer,
                offsetsInBytes : offsetsInBytes,
                vertexSizeInBytes : vertexSizeInBytes
            };
        }
        
        // No attributes to interleave.
        return undefined;
    }
    
    /**
     * Creates a vertex array from a geometry.  A geometry contains vertex attributes and optional index data
     * in system memory, whereas a vertex array contains vertex buffers and an optional index buffer in WebGL
     * memory for use with rendering.
     * <br /><br />
     * The <code>geometry</code> argument should use the standard layout like the geometry returned by {@link BoxGeometry}.
     * <br /><br />
     * <code>creationArguments</code> can have four properties:
     * <ul>
     *   <li><code>geometry</code>:  The source geometry containing data used to create the vertex array.</li>
     *   <li><code>attributeLocations</code>:  An object that maps geometry attribute names to vertex shader attribute locations.</li>
     *   <li><code>bufferUsage</code>:  The expected usage pattern of the vertex array's buffers.  On some WebGL implementations, this can significantly affect performance.  See {@link BufferUsage}.  Default: <code>BufferUsage.DYNAMIC_DRAW</code>.</li>
     *   <li><code>vertexLayout</code>:  Determines if all attributes are interleaved in a single vertex buffer or if each attribute is stored in a separate vertex buffer.  Default: <code>VertexLayout.SEPARATE</code>.</li>
     * </ul>
     * <br />
     * If <code>creationArguments</code> is not specified or the <code>geometry</code> contains no data, the returned vertex array is empty.
     *
     * @memberof Context
     *
     * @param {Object} [creationArguments=undefined] An object defining the geometry, attribute indices, buffer usage, and vertex layout used to create the vertex array.
     *
     * @exception {RuntimeError} Each attribute list must have the same number of vertices.
     * @exception {DeveloperError} The geometry must have zero or one index lists.
     * @exception {DeveloperError} Index n is used by more than one attribute.
     *
     * @see Context#createVertexArray
     * @see Context#createVertexBuffer
     * @see Context#createIndexBuffer
     * @see GeometryPipeline.createAttributeLocations
     * @see ShaderProgram
     *
     * @example
     * // Example 1. Creates a vertex array for rendering a box.  The default dynamic draw
     * // usage is used for the created vertex and index buffer.  The attributes are not
     * // interleaved by default.
     * var geometry = new BoxGeometry();
     * var va = context.createVertexArrayFromGeometry({
     *     geometry           : geometry,
     *     attributeLocations : GeometryPipeline.createAttributeLocations(geometry),
     * });
     *
     * ////////////////////////////////////////////////////////////////////////////////
     *
     * // Example 2. Creates a vertex array with interleaved attributes in a
     * // single vertex buffer.  The vertex and index buffer have static draw usage.
     * var va = context.createVertexArrayFromGeometry({
     *     geometry           : geometry,
     *     attributeLocations : GeometryPipeline.createAttributeLocations(geometry),
     *     bufferUsage        : BufferUsage.STATIC_DRAW,
     *     vertexLayout       : VertexLayout.INTERLEAVED
     * });
     *
     * ////////////////////////////////////////////////////////////////////////////////
     *
     * // Example 3.  When the caller destroys the vertex array, it also destroys the
     * // attached vertex buffer(s) and index buffer.
     * va = va.destroy();
     *
    Context.prototype.createVertexArrayFromGeometry = function(creationArguments) {
        var ca = defaultValue(creationArguments, defaultValue.EMPTY_OBJECT);
        var geometry = defaultValue(ca.geometry, defaultValue.EMPTY_OBJECT);
        
        var bufferUsage = defaultValue(ca.bufferUsage, BufferUsage.DYNAMIC_DRAW);
        
        var attributeLocations = defaultValue(ca.attributeLocations, defaultValue.EMPTY_OBJECT);
        var interleave = (defined(ca.vertexLayout)) && (ca.vertexLayout === VertexLayout.INTERLEAVED);
        var createdVAAttributes = ca.vertexArrayAttributes;
        
        var name;
        var attribute;
        var vertexBuffer;
        var vaAttributes = (defined(createdVAAttributes)) ? createdVAAttributes : [];
        var attributes = geometry.attributes;
        
        if (interleave) {
            // Use a single vertex buffer with interleaved vertices.
            var interleavedAttributes = interleaveAttributes(attributes);
            if (defined(interleavedAttributes)) {
                vertexBuffer = this.createVertexBuffer(interleavedAttributes.buffer, bufferUsage);
                var offsetsInBytes = interleavedAttributes.offsetsInBytes;
                var strideInBytes = interleavedAttributes.vertexSizeInBytes;
                
                for (name in attributes) {
                    if (attributes.hasOwnProperty(name) && defined(attributes[name])) {
                        attribute = attributes[name];
                        
                        if (defined(attribute.values)) {
                            // Common case: per-vertex attributes
                            vaAttributes.push({
                                index : attributeLocations[name],
                                vertexBuffer : vertexBuffer,
                                componentDatatype : attribute.componentDatatype,
                                componentsPerAttribute : attribute.componentsPerAttribute,
                                normalize : attribute.normalize,
                                offsetInBytes : offsetsInBytes[name],
                                strideInBytes : strideInBytes
                            });
                        } else {
                            // Constant attribute for all vertices
                            vaAttributes.push({
                                index : attributeLocations[name],
                                value : attribute.value,
                                componentDatatype : attribute.componentDatatype,
                                normalize : attribute.normalize
                            });
                        }
                    }
                }
            }
        } else {
            // One vertex buffer per attribute.
            for (name in attributes) {
                if (attributes.hasOwnProperty(name) && defined(attributes[name])) {
                    attribute = attributes[name];
                    
                    var componentDatatype = attribute.componentDatatype;
                    if (componentDatatype.value === ComponentDatatype.DOUBLE.value) {
                        componentDatatype = ComponentDatatype.FLOAT;
                    }
                    
                    vertexBuffer = undefined;
                    if (defined(attribute.values)) {
                        vertexBuffer = this.createVertexBuffer(ComponentDatatype.createTypedArray(componentDatatype, attribute.values), bufferUsage);
                    }
                    
                    vaAttributes.push({
                        index : attributeLocations[name],
                        vertexBuffer : vertexBuffer,
                        value : attribute.value,
                        componentDatatype : componentDatatype,
                        componentsPerAttribute : attribute.componentsPerAttribute,
                        normalize : attribute.normalize
                    });
                }
            }
        }
        
        var indexBuffer;
        var indices = geometry.indices;
        if (defined(indices)) {
            if ((Geometry.computeNumberOfVertices(geometry) > CesiumMath.SIXTY_FOUR_KILOBYTES) && this.elementIndexUint) {
                indexBuffer = this.createIndexBuffer(new Uint32Array(indices), bufferUsage, IndexDatatype.UNSIGNED_INT);
            } else{
                indexBuffer = this.createIndexBuffer(new Uint16Array(indices), bufferUsage, IndexDatatype.UNSIGNED_SHORT);
            }
        }
        
        return this.createVertexArray(vaAttributes, indexBuffer);
    };
    
    var viewportQuadAttributeLocations = {
        position : 0,
        textureCoordinates : 1
    };
    
    /**
     * @private
     *
    Context.prototype.createViewportQuadCommand = function(fragmentShaderSource, overrides) {
        // Per-context cache for viewport quads
        var vertexArray = this.cache.viewportQuad_vertexArray;
        
        if (!defined(vertexArray)) {
            var geometry = new Geometry({
                attributes : {
                    position : new GeometryAttribute({
                        componentDatatype : ComponentDatatype.FLOAT,
                        componentsPerAttribute : 2,
                        values : [
                                  -1.0, -1.0,
                                  1.0, -1.0,
                                  1.0,  1.0,
                                  -1.0,  1.0
                                  ]
                    }),
                    
                    textureCoordinates : new GeometryAttribute({
                        componentDatatype : ComponentDatatype.FLOAT,
                        componentsPerAttribute : 2,
                        values : [
                                  0.0, 0.0,
                                  1.0, 0.0,
                                  1.0, 1.0,
                                  0.0, 1.0
                                  ]
                    })
                },
                primitiveType : PrimitiveType.TRIANGLES
            });
            
            vertexArray = this.createVertexArrayFromGeometry({
                geometry : geometry,
                attributeLocations : {
                    position : 0,
                    textureCoordinates : 1
                },
                bufferUsage : BufferUsage.STATIC_DRAW
            });
            
            this.cache.viewportQuad_vertexArray = vertexArray;
        }
        
        overrides = defaultValue(overrides, defaultValue.EMPTY_OBJECT);
        
        var command = new DrawCommand();
        command.vertexArray = vertexArray;
        command.primitiveType = PrimitiveType.TRIANGLE_FAN;
        command.renderState = overrides.renderState;
        command.shaderProgram = this.shaderCache.getShaderProgram(ViewportQuadVS, fragmentShaderSource, viewportQuadAttributeLocations);
        command.uniformMap = overrides.uniformMap;
        command.owner = overrides.owner;
        command.framebuffer = overrides.framebuffer;
        
        return command;
    };
    
    /**
     * DOC_TBA
     *
     * @memberof Context
     *
     * @see Sene#pick
     *
    Context.prototype.createPickFramebuffer = function() {
        return new PickFramebuffer(this);
    };
    
    /**
     * Gets the object associated with a pick color.
     *
     * @memberof Context
     *
     * @param {Color} The pick color.
     *
     * @returns {Object} The object associated with the pick color, or undefined if no object is associated with that color.
     *
     * @example
     * var object = context.getObjectByPickColor(pickColor);
     *
     * @see Context#createPickId
     *
    Context.prototype.getObjectByPickColor = function(pickColor) {
        //>>includeStart('debug', pragmas.debug);
        if (!defined(pickColor)) {
            throw new DeveloperError('pickColor is required.');
        }
        //>>includeEnd('debug');
        
        return this._pickObjects[pickColor.toRgba()];
    };
    
    function PickId(pickObjects, key, color) {
        this._pickObjects = pickObjects;
        this.key = key;
        this.color = color;
    }
    
    defineProperties(PickId.prototype, {
        object : {
            get : function() {
                return this._pickObjects[this.key];
            },
            set : function(value) {
                this._pickObjects[this.key] = value;
            }
        }
    });
    
    PickId.prototype.destroy = function() {
        delete this._pickObjects[this.key];
        return undefined;
    };
    
    /**
     * Creates a unique ID associated with the input object for use with color-buffer picking.
     * The ID has an RGBA color value unique to this context.  You must call destroy()
     * on the pick ID when destroying the input object.
     *
     * @memberof Context
     *
     * @param {Object} object The object to associate with the pick ID.
     *
     * @returns {Object} A PickId object with a <code>color</code> property.
     *
     * @exception {RuntimeError} Out of unique Pick IDs.
     *
     * @see Context#getObjectByPickColor
     *
     * @example
     * this._pickId = context.createPickId({
     *   primitive : this,
     *   id : this.id
     * });
     *
    Context.prototype.createPickId = function(object) {
        //>>includeStart('debug', pragmas.debug);
        if (!defined(object)) {
            throw new DeveloperError('object is required.');
        }
        //>>includeEnd('debug');
        
        // the increment and assignment have to be separate statements to
        // actually detect overflow in the Uint32 value
        ++this._nextPickColor[0];
        var key = this._nextPickColor[0];
        if (key === 0) {
            // In case of overflow
            throw new RuntimeError('Out of unique Pick IDs.');
        }
        
        this._pickObjects[key] = object;
        return new PickId(this._pickObjects, key, Color.fromRgba(key));
    };
    
    Context.prototype.isDestroyed = function() {
        return false;
    };
    
    Context.prototype.destroy = function() {
        // Destroy all objects in the cache that have a destroy method.
        var cache = this.cache;
        for (var property in cache) {
            if (cache.hasOwnProperty(property)) {
                var propertyValue = cache[property];
                if (defined(propertyValue.destroy)) {
                    propertyValue.destroy();
                }
            }
        }
        
        this._shaderCache = this._shaderCache.destroy();
        this._defaultTexture = this._defaultTexture && this._defaultTexture.destroy();
        this._defaultCubeMap = this._defaultCubeMap && this._defaultCubeMap.destroy();
        
        return destroyObject(this);
    };
    
    return Context;
});*/

-(NSArray *)getGLExtensions
{
    return [[NSString stringWithUTF8String:(char *)glGetString(GL_EXTENSIONS)] componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
}

-(BOOL)checkGLExtension:(NSString *)glExtension
{
    if (!self.cachedGLESExtensions)
    {
        _cachedGLESExtensions = [self getGLExtensions];
    }
    NSUInteger index = [_cachedGLESExtensions indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop)
                        {
                            if ([obj isEqualToString:glExtension])
                            {
                                return YES;
                            }
                            return NO;
                        }];
    return index != NSNotFound;
}

@end
