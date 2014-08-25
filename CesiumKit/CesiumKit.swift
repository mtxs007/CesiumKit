//
//  CesiumKit.swift
//  CesiumKit
//
//  Created by Ryan Walklin on 12/08/14.
//  Copyright (c) 2014 Test Toast. All rights reserved.
//

import Foundation
import OpenGLES

/**
Describes Globe object options

:param: Clock [options.clock=new Clock()] The clock to use to control current time.
:param: imageryProvider [options.imageryProvider=new BingMapsImageryProvider()] The imagery provider to serve as the base layer. If set to false, no imagery provider will be added.
:param: terrainProvider [options.terrainProvider=new EllipsoidTerrainProvider] The terrain provider.
:param: skyBox [options.skyBox] The skybox used to render the stars.  When <code>undefined</code>, the default stars are used.
:param: sceneMode [options.sceneMode=SceneMode.SCENE3D] The initial scene mode.
:param: scene3DOnly Boolean [options.scene3DOnly=false] When <code>true</code>, each geometry instance will only be rendered in 3D to save GPU memory.
:param: mapProjection [options.mapProjection=new GeographicProjection()] The map projection to use in 2D and Columbus View modes.
:param: Boolean [options.useDefaultRenderLoop=true] True if this widget should control the render loop, false otherwise.
:param: Number [options.targetFrameRate] The target frame rate when using the default render loop.
:param: Boolean [options.showRenderLoopErrors=true] If true, this widget will automatically display an HTML panel to the user containing the error, if a render loop error occurs.
*/
struct CesiumOptions {
    
    var clock = Clock()
    var imageryProvider: BingMapsImageryProvider? = nil // FIXME: mapsBingMapsImageryProvider(/*url : "//dev.virtualearth.net"*/)
    var terrainProvider: TerrainProvider = EllipsoidTerrainProvider()
    var skyBox: SkyBox? = nil
    var sceneMode: SceneMode = .Scene3D
    var scene3DOnly = false
    var mapProjection = GeographicProjection()
    var useDefaultRenderLoop = true
    var targetFrameRate = 60
    var showRenderLoopErrors = true
    
    /*/// :param: Object [options.contextOptions] Context and WebGL creation properties corresponding to <code>options</code> passed to {@link Scene.
    let contextOptions = ContextOptions()*/
    
    /*/// :param: Element|String [options.creditContainer] The DOM element or ID that will contain the {@link CreditDisplay.  If not specified the credits are added to the bottom of the widget itself.*/
}

/**
* A widget containing a Cesium scene.
*
* @alias CesiumWidget
* @constructor
*
* @param {Element|String} container The DOM element or ID that will contain the widget.
* @param {Object} [options] Object with the following properties:
* @param {Clock} [options.clock=new Clock()] The clock to use to control current time.
* @param {ImageryProvider} [options.imageryProvider=new BingMapsImageryProvider()] The imagery provider to serve as the base layer. If set to false, no imagery provider will be added.
* @param {TerrainProvider} [options.terrainProvider=new EllipsoidTerrainProvider] The terrain provider.
* @param {SkyBox} [options.skyBox] The skybox used to render the stars.  When <code>undefined</code>, the default stars are used.
* @param {SceneMode} [options.sceneMode=SceneMode.SCENE3D] The initial scene mode.
* @param {Boolean} [options.scene3DOnly=false] When <code>true</code>, each geometry instance will only be rendered in 3D to save GPU memory.
* @param {MapProjection} [options.mapProjection=new GeographicProjection()] The map projection to use in 2D and Columbus View modes.
* @param {Boolean} [options.useDefaultRenderLoop=true] True if this widget should control the render loop, false otherwise.
* @param {Number} [options.targetFrameRate] The target frame rate when using the default render loop.
* @param {Boolean} [options.showRenderLoopErrors=true] If true, this widget will automatically display an HTML panel to the user containing the error, if a render loop error occurs.
* @param {Object} [options.contextOptions] Context and WebGL creation properties corresponding to <code>options</code> passed to {@link Scene}.
* @param {Element|String} [options.creditContainer] The DOM element or ID that will contain the {@link CreditDisplay}.  If not specified, the credits are added
*        to the bottom of the widget itself.
*
* @exception {DeveloperError} Element with id "container" does not exist in the document.
*
* @demo {@link http://cesiumjs.org/Cesium/Apps/Sandcastle/index.html?src=Cesium%20Widget.html|Cesium Sandcastle Cesium Widget Demo}
*
* @example
* // For each example, include a link to CesiumWidget.css stylesheet in HTML head,
* // and in the body, include: <div id="cesiumContainer"></div>
*
* //Widget with no terrain and default Bing Maps imagery provider.
* var widget = new Cesium.CesiumWidget('cesiumContainer');
*
* //Widget with OpenStreetMaps imagery provider and Cesium terrain provider hosted by AGI.
* var widget = new Cesium.CesiumWidget('cesiumContainer', {
*     imageryProvider : new Cesium.OpenStreetMapImageryProvider(),
*     terrainProvider : new Cesium.CesiumTerrainProvider({
*         url : '//cesiumjs.org/smallterrain',
*         credit : 'Terrain data courtesy Analytical Graphics, Inc.'
*     }),
*     // Use high-res stars downloaded from https://github.com/AnalyticalGraphicsInc/cesium-assets
*     skyBox : new Cesium.SkyBox({
*         sources : {
*           positiveX : 'stars/TychoSkymapII.t3_08192x04096_80_px.jpg',
*           negativeX : 'stars/TychoSkymapII.t3_08192x04096_80_mx.jpg',
*           positiveY : 'stars/TychoSkymapII.t3_08192x04096_80_py.jpg',
*           negativeY : 'stars/TychoSkymapII.t3_08192x04096_80_my.jpg',
*           positiveZ : 'stars/TychoSkymapII.t3_08192x04096_80_pz.jpg',
*           negativeZ : 'stars/TychoSkymapII.t3_08192x04096_80_mz.jpg'
*         }
*     }),
*     // Show Columbus View map with Web Mercator projection
*     sceneMode : Cesium.SceneMode.COLUMBUS_VIEW,
*     mapProjection : new Cesium.WebMercatorProjection()
* });
*/
public class Cesium {

    var canRender = false
    var renderLoopRunning = false
    var showRenderLoopErrors = false
    var forceResize = false
    
    var lastFrameTime: Double?
    
    /**
    * Gets or sets whether or not this widget should control the render loop.
    * If set to true the widget will use {@link requestAnimationFrame} to
    * perform rendering and resizing of the widget, as well as drive the
    * simulation clock. If set to false, you must manually call the
    * <code>resize</code>, <code>render</code> methods as part of a custom
    * render loop.  If an error occurs during rendering, {@link Scene}'s
    * <code>renderError</code> event will be raised and this property
    * will be set to false.  It must be set back to true to continue rendering
    * after the error.
    * @memberof CesiumWidget.prototype
    *
    * @type {Boolean}
    */
    
    var useDefaultRenderLoop: Bool {
        didSet {
            if self.useDefaultRenderLoop && !self.renderLoopRunning {
                startRenderLoop()
            }
        }
    }
    
    /**
    * Gets or sets the target frame rate of the widget when <code>useDefaultRenderLoop</code>
    * is true. If undefined, the browser's {@link requestAnimationFrame} implementation
    * determines the frame rate.  This value must be greater than 0 and a value higher than
    * the underlying requestAnimationFrame implementatin will have no affect.
    * @memberof CesiumWidget.prototype
    *
    * @type {Number}
    */
    var targetFrameRate: Int? = nil
    
    let context: EAGLContext
    
    /**
    * Gets the scene.
    * @memberof CesiumWidget.prototype
    *
    * @type {Scene}
    */
    public let scene: Scene
    
    let ellipsoid: Ellipsoid = Ellipsoid.wgs84Ellipsoid()

    var globe: Globe
    
    //let skyBox: SkyBox
    
    // FIXME: ImageryProvider
    var imageryProvider: BingMapsImageryProvider? = nil//ImageryProvider? = nil
    
    var sceneMode: SceneMode
    
    var scene3DOnly: Bool
   
    /**
    * Gets or sets a scaling factor for rendering resolution.  Values less than 1.0 can improve
    * performance on less powerful devices while values greater than 1.0 will render at a higher
    * resolution and then scale down, resulting in improved visual fidelity.
    * For example, if the widget is laid out at a size of 640x480, setting this value to 0.5
    * will cause the scene to be rendered at 320x240 and then scaled up while setting
    * it to 2.0 will cause the scene to be rendered at 1280x960 and then scaled down.
    * @memberof CesiumWidget.prototype
    *
    * @type {Number}
    * @default 1.0
    */
    var resolutionScale: Double {
        didSet {
            if self.resolutionScale != 1.0 {
                self.forceResize = true
            }
        }
    }
    
    /**
    * Gets the credit container.
    * @memberof CesiumWidget.prototype
    *
    * @type {Element}
    */
    // FIXME public var creditContainer: CreditContainer
    
    /**
    * Gets the screen space event handler.
    * @memberof CesiumWidget.prototype
    *
    * @type {ScreenSpaceEventHandler}
    */
    var screenSpaceEventHandler: ScreenSpaceEventHandler
    
    /**
    * Gets the clock.
    * @memberof CesiumWidget.prototype
    *
    * @type {Clock}
    */
    public let clock: Clock
    
    init (context: EAGLContext, options: CesiumOptions) {
        
        self.context = context
        /*
        var creditContainer = document.createElement('div');
        creditContainer.className = 'cesium-widget-credits';
        
        var creditContainerContainer = defined(options.creditContainer) ? getElement(options.creditContainer) : element;
        creditContainerContainer.appendChild(creditContainer);*/
        
        self.canRender = false
        self.renderLoopRunning = false
        self.useDefaultRenderLoop = options.useDefaultRenderLoop
        self.showRenderLoopErrors = options.showRenderLoopErrors
        self.resolutionScale = 1.0
        self.forceResize = false
        self.clock = options.clock
        lastFrameTime = nil
        
        self.scene = Scene(/*{
            canvas : canvas,
            contextOptions : options.contextOptions,
            creditContainer : creditContainer,
            mapProjection : options.mapProjection,*/
            scene3DOnly: true// FIXME: compiler options.scene3DOnly ?? false
/*            }*/)
        
        self.scene.camera.constrainedAxis = Cartesian3.unitZ()
        
        /*var creditDisplay = scene.frameState.creditDisplay;
        
        var cesiumCredit = new Credit('Cesium', cesiumLogoData, 'http://cesiumjs.org/');
        creditDisplay.addDefaultCredit(cesiumCredit);*/
        
        let globe = Globe(ellipsoid: ellipsoid)
        self.globe = globe
        self.scene.globe = globe
        
        // FIXME: Skybox disabled
        /*(var skyBox = options.skyBox;
        if (!defined(skyBox)) {
        skyBox = new SkyBox({
        sources : {
        positiveX : getDefaultSkyBoxUrl('px'),
        negativeX : getDefaultSkyBoxUrl('mx'),
        positiveY : getDefaultSkyBoxUrl('py'),
        negativeY : getDefaultSkyBoxUrl('my'),
        positiveZ : getDefaultSkyBoxUrl('pz'),
        negativeZ : getDefaultSkyBoxUrl('mz')
        }*/
        
        // FIXME: UFOs disabled
        /*scene.skyBox = skyBox;
        scene.skyAtmosphere = new SkyAtmosphere(ellipsoid);
        scene.sun = new Sun();
        scene.moon = new Moon();*/

        if options.imageryProvider != nil {
            scene.imageryLayers.addImageryProvider(options.imageryProvider!, index: nil)
        }
        
        //Set the terrain provider
        scene.terrainProvider = options.terrainProvider
        
        self.screenSpaceEventHandler = ScreenSpaceEventHandler(/*canvas*/)
        self.sceneMode = options.sceneMode
        self.scene3DOnly = options.scene3DOnly
        
        if self.sceneMode == SceneMode.Scene2D {
            self.scene.morphTo2D(duration: 0)
        }
        if self.sceneMode == SceneMode.ColumbusView {
            self.scene.morphToColumbusView(duration: 0)
        }
        
        useDefaultRenderLoop = options.useDefaultRenderLoop
        
        self.targetFrameRate = options.targetFrameRate
        
        configureCanvasSize()
        configureCameraFrustum()

        // FIXME: Render errors
        /*scene.renderError.addEventListener( { (scene: Scene, error: String) {
            self.useDefaultRenderLoop = false;
            self.renderLoopRunning = false;
            if (showRenderLoopErrors) {
                var title = "An error occurred while rendering.  Rendering has stopped."
                var message = "This may indicate an incompatibility with your hardware or web browser, or it may indicate a bug in the application.  Visit <a href=\"http://get.webgl.org\">http://get.webgl.org</a> to verify that your web browser and hardware support WebGL.  Consider trying a different web browser or updating your video drivers.  Detailed error information is below:"
                self.showErrorPanel(title, message, error)
            }
        }
        }*/
    }

    func getDefaultSkyBoxUrl(suffix: String) -> String {
        //FIXME: Skybox URL
        //return buildModuleUrl('Assets/Textures/SkyBox/tycho2t3_80_' + suffix + '.jpg')
        return suffix
    }
    
    func startRenderLoop() {
        
        renderLoopRunning = true
        lastFrameTime = NSDate.timeIntervalSinceReferenceDate() + NSTimeIntervalSince1970
        /*
        func render() {
            //if (widget.isDestroyed()) {
            //  return;
            //}
            
            if (useDefaultRenderLoop) {
                if (targetFrameRate == nil) {
                    resize()
                    render()
                    requestAnimationFrame(render)
                } else {
                    var lastFrameTime = self.lastFrameTime
                    var interval = 1000.0 / targetFrameRate
                    var now = NSDate.timeIntervalSinceReferenceDate() + NSTimeIntervalSince1970
                    var delta = now - lastFrameTime
                    
                    if (delta > interval) {
                        resize()
                        render()
                        lastFrameTime = now - (delta % interval)
                    }
                    requestAnimationFrame(render)
                }
            } else {
                renderLoopRunning = false
            }
        }
        requestAnimationFrame(render)*/
    }

    func configureCanvasSize() {
        //FIXME: Fix width
    /*var canvas = widget._canvas;
    var width = canvas.clientWidth;
    var height = canvas.clientHeight;
    var zoomFactor = defaultValue(window.devicePixelRatio, 1.0) * widget._resolutionScale;
    
    widget._canvasWidth = width;
    widget._canvasHeight = height;
    
    width *= zoomFactor;
    height *= zoomFactor;
    
    canvas.width = width;
    canvas.height = height;
    
    widget._canRender = width !== 0 && height !== 0;*/
}

func configureCameraFrustum() {
    // FIXME: Fix cameraFrustum
    /*var canvas = widget._canvas;
    var width = canvas.width;
    var height = canvas.height;
    if (width !== 0 && height !== 0) {
        var frustum = widget._scene.camera.frustum;
        if (defined(frustum.aspectRatio)) {
            frustum.aspectRatio = width / height;
        } else {
            frustum.top = frustum.right * (height / width);
            frustum.bottom = -frustum.top;
        }
    }*/
}
/*
var cesiumLogoData = 'data:image/png;base64,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';
*/

    /**
    * Show an error panel to the user containing a title and a longer error message,
    * which can be dismissed using an OK button.  This panel is displayed automatically
    * when a render loop error occurs, if showRenderLoopErrors was not false when the
    * widget was constructed.
    *
    * @param {String} title The title to be displayed on the error panel.  This string is interpreted as text.
    * @param {String} message A helpful, user-facing message to display prior to the detailed error information.  This string is interpreted as HTML.
    * @param {String} [error] The error to be displayed on the error panel.  This string is formatted using {@link formatError} and then displayed as text.
    */
    public func showErrorPanel(title: String, message: String, error: String) {
        println(title)
        println(message)
        println(error)
        /*
        // FIXME Error display
        var element = this._element;
        var overlay = document.createElement('div');
        overlay.className = 'cesium-widget-errorPanel';
        
        var content = document.createElement('div');
        content.className = 'cesium-widget-errorPanel-content';
        overlay.appendChild(content);
        
        var errorHeader = document.createElement('div');
        errorHeader.className = 'cesium-widget-errorPanel-header';
        errorHeader.appendChild(document.createTextNode(title));
        content.appendChild(errorHeader);
        
        var errorPanelScroller = document.createElement('div');
        errorPanelScroller.className = 'cesium-widget-errorPanel-scroll';
        content.appendChild(errorPanelScroller);
        var resizeCallback = function() {
        errorPanelScroller.style.maxHeight = Math.max(Math.round(element.clientHeight * 0.9 - 100), 30) + 'px';
        };
        resizeCallback();
        if (defined(window.addEventListener)) {
        window.addEventListener('resize', resizeCallback, false);
        }
        
        var errorMessage = document.createElement('div');
        errorMessage.className = 'cesium-widget-errorPanel-message';
        errorMessage.innerHTML = '<p>' + message + '</p>';
        errorPanelScroller.appendChild(errorMessage);
        
        var errorDetails = '(no error details available)';
        if (defined(error)) {
        errorDetails = formatError(error);
        }
        
        var errorMessageDetails = document.createElement('div');
        errorMessageDetails.className = 'cesium-widget-errorPanel-message';
        errorMessageDetails.appendChild(document.createTextNode(errorDetails));
        errorPanelScroller.appendChild(errorMessageDetails);
        
        var buttonPanel = document.createElement('div');
        buttonPanel.className = 'cesium-widget-errorPanel-buttonPanel';
        content.appendChild(buttonPanel);
        
        var okButton = document.createElement('button');
        okButton.setAttribute('type', 'button');
        okButton.className = 'cesium-button';
        okButton.appendChild(document.createTextNode('OK'));
        okButton.onclick = function() {
        if (defined(resizeCallback) && defined(window.removeEventListener)) {
        window.removeEventListener('resize', resizeCallback, false);
        }
        element.removeChild(overlay);
        };
        
        buttonPanel.appendChild(okButton);
        
        element.appendChild(overlay);
        
        console.error(title + '\n' + message + '\n' + errorDetails);*/
    }

    /**
    * @returns {Boolean} true if the object has been destroyed, false otherwise.
    */
    func isDestroyed () -> Bool {
        return false
    }

/**
* Destroys the widget.  Should be called if permanently
* removing the widget from layout.
*/
    deinit {
        //self.scene.deinit
    /*this._scene = this._scene && this._scene.destroy();
    this._container.removeChild(this._element);
    destroyObject(this);*/
}

    /**
    * Updates the canvas size, camera aspect ratio, and viewport size.
    * This function is called automatically as needed unless
    * <code>useDefaultRenderLoop</code> is set to false.
    */
    
    func resize() {
// FIXME: Resize
/*
//        var canvas = this._canvas;
//        var width = canvas.clientWidth;
//        var height = canvas.clientHeight;
        if (!this._forceResize && this._canvasWidth === width && this._canvasHeight === height) {
            return;
        }
        this._forceResize = false;
        
        configureCanvasSize(this);
        configureCameraFrustum(this);*/
    }
    /**
    * Renders the scene.  This function is called automatically
    * unless <code>useDefaultRenderLoop</code> is set to false;
    */
    public func render() {
        scene.initializeFrame()
        var currentTime = clock.tick()
        if canRender {
            scene.render(currentTime)
        }
    }
}
