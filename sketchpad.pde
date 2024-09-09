import javax.swing.*;
import javax.swing.border.EmptyBorder;
import javax.swing.filechooser.FileSystemView;

// Size estimations for rendering:
//400% 16mb
//300% 9mb
//200% 4mb
//100% 1mb
//50% 0.25mb
//25% 0.0625mb
//
// Formula = width * height * 4 * scale * timeLength * framespersecond 
//

public class Sketchpad extends Screen {
  private String sketchiePath = "";
  private TWEngine.PluginModule.Plugin plugin;
  private FFmpegEngine ffmpeg;
  private String code = "";
  private AtomicBoolean compiling = new AtomicBoolean(false);
  private AtomicBoolean successful = new AtomicBoolean(false);
  private AtomicBoolean once = new AtomicBoolean(true);
  private SpriteSystemPlaceholder sprites;
  private SpriteSystemPlaceholder gui;
  private PGraphics canvas;
  private float canvasScale = 1.0;
  private float canvasX = 0.0;
  private float canvasY = 0.0;
  private float canvasPaneScroll = 0.;
  private float codePaneScroll = 0.;
  private ArrayList<String> imagesInSketch = new ArrayList<String>();  // This is so that we can know what to remove when we exit this screen.
  private ArrayList<PImage> loadedImages = new ArrayList<PImage>();
  private JSONObject configJSON = null;
  private AtomicBoolean loading = new AtomicBoolean(true);
  private AtomicInteger processAfterLoadingIndex = new AtomicInteger(0);
  float textAreaZoom = 22.0;
  private boolean configMenu = false;
  private boolean renderMenu = false;
  private int canvasSmooth = 1;
  private String renderFormat = "MPEG-4";
  private float upscalePixels = 1.;
  private boolean rendering = false;
  private boolean converting = false;
  private int timeBeforeStartingRender = 0;
  private PGraphics shaderCanvas;
  private PGraphics scaleCanvas;
  private int renderFrameCount = 0;
  private float renderFramerate = 0.;
  private float musicVolume = 0.5;
  private String[] musicFiles = new String[0];
  private String selectedMusic = "";
  
  private boolean playing = false;
  private boolean loop = false;
  private float time = 0.;
  private float timeLength = 10.*60.;
  
  // Canvas 
  private float beginDragX = 0.;
  private float beginDragY = 0.;
  private float prevCanvasX = 0.;
  private float prevCanvasY = 0.;
  private boolean isDragging = false;
  
  // Selected pane
  private int selectedPane = 0;
  private int lastSelectedPane = 0;   // Mostly just so I can use the space bar.
  
  final static int CANVAS_PANE = 1;
  final static int CODE_PANE = 2;
  final static int TIMELINE_PANE = 3;
  
  
  private String[] defaultCode = {
    "public void start() {",
    "  ",
    "}",
    "",
    "public void run() {",
    "  g.background(120, 100, 140);",
    "  ",
    "}"
  };
  

  public Sketchpad(TWEngine engine, String path) {
    this(engine);
    
    loadSketchieInSeperateThread(path);
  }
  
  public Sketchpad(TWEngine engine) {
    super(engine);
    myUpperBarWeight = 100.;
    
    gui = new SpriteSystemPlaceholder(engine, engine.APPPATH+engine.PATH_SPRITES_ATTRIB+"gui/sketchpad/");
    gui.interactable = false;
    
    
    plugin = plugins.createPlugin();
    
    createCanvas(1024, 1024, 1);
    resetView();
    
    canvasY = myUpperBarWeight;
    
    input.keyboardMessage = "";
    code = "";
    // Load default code into keyboardMessage
    for (String s : defaultCode) {
      code += s+"\n";
    }
    
    ffmpeg = new FFmpegEngine();
    
    lastSelectedPane = CODE_PANE;
    
    //sound.streamMusic(engine.APPPATH+"engine/music/test.mp3");
  }
  
  
  
  
  
  
  
  
  
  
  
  ////////////////////////////////////////////////////
  // SETUP AND LOADING
  
  private void createCanvas(int wi, int hi, int smooth) {
    //console.log("CANVAS "+wi+" "+hi);
    canvas = createGraphics(wi, hi, P2D);
    if (smooth == 0) {
      // Nearest neighbour (hey remember this ancient line of code?)
      ((PGraphicsOpenGL)canvas).textureSampling(2);    
    }
    else {
      canvas.smooth(smooth);
    }
    plugin.sketchioGraphics = canvas;
  }
  
  private void loadSketchieInSeperateThread(String path) {
    loading.set(true);
    processAfterLoadingIndex.set(0);
    Thread t1 = new Thread(new Runnable() {
      public void run() {
        loadSketchie(path);
        loading.set(false);
      }
    });
    t1.start();
  }
  
  // NOTE: there isn't an equivalent "saveSketchie" method because we don't have
  // to save the whole thing:
  // - sprite data is saved automatically by the sprite class
  // - images... well, I don't think they need to be saved.
  private void saveScripts() {
    // Not gonna bother putting a TODO but you know that the script isn't going to stick to
    // a keyboard forever.
    String[] strs = new String[1];
    strs[0] = code;
    app.saveStrings(sketchiePath+"scripts/main.pde", strs);
    
    console.log("Saved.");
  }
  
  private void saveConfig() {
    JSONObject json = new JSONObject();
    json.setInt("canvas_width", canvas.width);
    json.setInt("canvas_height", canvas.height);
    json.setInt("smooth", canvasSmooth);
    json.setFloat("time_length", timeLength);
    json.setString("music_file", selectedMusic);
    json.setBoolean("show_code_editor", codeEditorShown);
    
    app.saveJSONObject(json, sketchiePath+"sketch_config.json");
  }
  
  // TODO: only loads one script
  private String loadScript() {
    String scriptPath = "";
    String ccode = "";
    if (file.exists(sketchiePath+"scripts")) scriptPath = sketchiePath+"scripts/";
    if (file.exists(sketchiePath+"script")) scriptPath = sketchiePath+"script/";
    // If scripts exist.
    if (scriptPath.length() > 0) {
      File[] scripts = (new File(scriptPath)).listFiles();
      for (File f : scripts) {
        String scriptAbsolutePath = f.getAbsolutePath();
        
        if (file.getExt(scriptAbsolutePath).equals("pde")) {
          String[] lines = app.loadStrings(scriptAbsolutePath);
          ccode = "";
          for (String s : lines) {
            ccode += s+"\n";
          }
          
          
          // Big TODO here: we're just gonna load one script for now
          // until I get things working.
          break;
        }
      }
    }
    else {
      // Script doesn't exist: return default code instead
      for (String s : defaultCode) {
        ccode += s+"\n";
      }
    }
    println(" ---------------------- CODE: ----------------------");
    println(ccode);
    return ccode;
  }
  
  
  private void loadSketchie(String path) {
    imagesInSketch.clear();
    loadedImages.clear();
    processAfterLoadingIndex.set(0);
    
    // Undirectorify path
    if (path.charAt(path.length()-1) == '/') {
      path.substring(0, path.length()-1);
    }
    
    if (!file.getExt(path).equals(engine.SKETCHIO_EXTENSION) || !file.isDirectory(path)) {
      console.warn("Not a valid sketchie file: "+path);
      return;
    }
    
    // Re-directorify path
    path = file.directorify(path);
    sketchiePath = path;
    
    //////////////////
    // IMAGES
    // Load images
    String imgPath = "";
    if (file.exists(path+"imgs")) imgPath = path+"imgs";
    if (file.exists(path+"img")) imgPath = path+"img";
    
    // Only if imgs folder exists
    if (imgPath.length() > 0) {
      // List out all the files, get each image.
      File[] imgs = (new File(imgPath)).listFiles();
      int numberImages = 0;
      for (File f : imgs) {
        if (f == null) continue;
        
        String pathToSingularImage = f.getAbsolutePath().replaceAll("\\\\", "/");
        String name = file.getIsolatedFilename(pathToSingularImage);
        
        // Only load images
        if (!file.isImage(pathToSingularImage)) {
          continue;
        }
        
        // Actual loading (you'll want to run loadSketchie in a seperate thread);
        PImage img = loadImage(pathToSingularImage);
        
        
        // Error checking
        if (img == null) {
          console.warn("Error while loading image "+name);
          continue;
        }
        if (img.width <= 0 && img.height <= 0) {
          console.warn("Error while loading image "+name);
          continue;
        }
        
        // To avoid race conditions, we need to put the images in a temp linked list
        // Add to list so we know what to clear from memory once we're done.
        imagesInSketch.add(name);
        loadedImages.add(img);
        numberImages++;
      }
      processAfterLoadingIndex.set(numberImages);
    }
    
    
    ///////////////////
    // SPRITES
    // Next: load sprites. Not too hard.
    String spritePath = "";
    if (file.exists(path+"sprites")) spritePath = path+"sprites/";
    if (file.exists(path+"sprite")) spritePath = path+"sprite/";
    
    // If sprites exist.
    if (spritePath.length() > 0) {
      // Load our new sprite system, EZ.
      sprites = new SpriteSystemPlaceholder(engine, spritePath);
      sprites.interactable = true;
    }
    
    
    //////////////////
    // SCRIPT
    // And now: script
    code = loadScript();
    
    //////////////////
    // MUSIC
    // Load em into a list
    if (file.exists(path+"music")) {
      File[] files = (new File(path+"music")).listFiles();
      musicFiles = new String[files.length];
      for (int i = 0; i < files.length; i++) {
        musicFiles[i] = files[i].getName();
      }
    }
    
    //////////////////
    // CONFIG
    // Load sketch config
    if (file.exists(path+"sketch_config.json")) {
      configJSON = loadJSONObject(path+"sketch_config.json");
      // Need to load the canvas from a seperate thread
      // But while we're here, now's a good time to set the music file.
      // and timelength cus why not.
      timeLength = configJSON.getFloat("time_length", 10.0);
      selectedMusic = configJSON.getString("music_file", "");
      codeEditorShown = configJSON.getBoolean("show_code_editor", true);
    }
  }
  
  private void compileCode(String code) {
    compiling.set(true);
    Thread t1 = new Thread(new Runnable() {
      public void run() {
        successful.set(plugin.compile(code));
        compiling.set(false);
        once.set(true);
      }
    });
    t1.start();
  }
  
  private void setMusic(String musicFileName) {
    sound.stopMusic();
    // Passing "" will stop any music.
    if (musicFileName.length() == 0) return;
    
    String path = sketchiePath+"music/"+musicFileName;
    if (file.exists(path)) {
      sound.streamMusic(path);
    }
    else {
      console.warn(musicFileName+" music file not found.");
      selectedMusic = "";
    }
  }
  
  
  
  
  
  
  
  
  
  //////////////////////////////////////////////
  // UTIL METHODS STUFF
  
  // methods for use by the API
  public float getTime() {
    return time;
  }
  
  public float getDelta() {
    // When we're rendering, all the file IO and expensive rendering operations will
    // inevitably make the actual framerate WAY lower than what we're aiming for and therefore
    if (rendering) return display.BASE_FRAMERATE/renderFramerate;
    else return display.getDelta();
  }
  
  public String getPath() {
    // Undirectorify path
    if (sketchiePath.charAt(sketchiePath.length()-1) == '/') {
      return sketchiePath.substring(0, sketchiePath.length()-1);
    }
    return sketchiePath;
  }
  
  public String getPathDirectorified() {
    return sketchiePath;
  }
  
  ////////////////////////////
  
  private boolean menuShown() {
    return configMenu || renderMenu || rendering;
  }
  
  private void resetView() {
    canvasX = canvas.width*canvasScale*0.5;
    canvasY = canvas.height*canvasScale*0.5;
    canvasScale = 1.0;
    // Only reset view if the mouse is in the canvas pane
    if (input.mouseX() < middle()) {
      canvasPaneScroll = -1000.;
    }
    else {
      input.scrollOffset = -1000.;
    }
  }
  
  // Creating this funciton because I think the width of
  // canvas v the code editor will likely change later
  // and i wanna maintain good code.
  
  private boolean codeEditorShown = true;
  private float middle() {
    if (codeEditorShown)
      return WIDTH/2;
    else
      return WIDTH;
  }
  
  private boolean codeEditorShown() {
    return codeEditorShown || rendering;
  }
  
  // Ancient code copied from Timeway it aint my fault pls believe me.
  private int countNewlines(String t) {
      int count = 0;
      for (int i = 0; i < t.length(); i++) {
          if (t.charAt(i) == '\n') {
              count++;
          }
      }
      return count;
  }
  
  private float getTextHeight(String txt) {
    float lineSpacing = 8;
    return ((app.textAscent()+app.textDescent()+lineSpacing)*float(countNewlines(txt)+1));
  }
  
  private void togglePlay() {
    if (playing) {
      pause();
    }
    else {
      play();
    }
  }
  
  private void pause() {
    if (playing) {
      playing = false;
      sound.pauseMusic();
    }
  }
  
  private void play() {
    if (!playing) {
      playing = true;
      sound.continueMusic();
    }
  }
  
  
  
  
  
  
  
  
  
  
  
  
  ////////////////////////////////////////////
  // CANVAS & CODE EDITOR
  
  private boolean inCanvasPane = false;
  
  private void displayCanvas() {
    if (input.altDown && input.shiftDown && input.keys[int('s')] == 2) {
      input.backspace();
      resetView();
    }
    
    boolean menuShown = configMenu || renderMenu;
    if ((lastSelectedPane == CANVAS_PANE || !codeEditorShown()) && input.keyActionOnce("playPause") && !menuShown) {
       togglePlay();
       input.backspace();   // Don't want the unintended space.
    }
    
    // Difficulty: we have 2 scroll areas: canvas zoom, and code editor.
    // if mouse is in canvas pane
    boolean canvasPane = input.mouseX() < middle() && !menuShown();
    if (canvasPane) {
      if (!inCanvasPane) {
        inCanvasPane = true;
        // We need to switch to our scroll value for the zoom
        codePaneScroll   = input.scrollOffset;     // Update code pane
        input.scrollOffset = canvasPaneScroll;
      }
      input.processScroll(100., 2500.);
    }
    
    float scroll = input.scrollOffset;
    if (!canvasPane) {
      scroll = canvasPaneScroll;
    }
    // Scroll is negative
    canvasScale = (2500.+scroll)/1000.;
    
    
    if (canvasPane && sprites.selectedSprite == null && input.mouseY() < HEIGHT-myLowerBarWeight && input.mouseY() > myUpperBarWeight) {
      if (input.primaryClick && !isDragging && selectedPane == 0) {
        beginDragX = input.mouseX();
        beginDragY = input.mouseY();
        prevCanvasX = canvasX;
        prevCanvasY = canvasY;
        isDragging = true;
        selectedPane = CANVAS_PANE;
        lastSelectedPane = CANVAS_PANE;
      }
    }
    if (isDragging && selectedPane == CANVAS_PANE) {
      canvasX = prevCanvasX+(input.mouseX()-beginDragX);
      canvasY = prevCanvasY+(input.mouseY()-beginDragY);
      
      if (!input.primaryDown || sprites.selectedSprite != null) {
        isDragging = false;
      }
    }
    
    sprites.setMouseScale(canvasScale, canvasScale);
    float xx = canvasX-canvas.width*canvasScale*0.5;
    float yy = canvasY-canvas.height*canvasScale*0.5;
    sprites.setMouseOffset(xx, yy);
    
    app.image(canvas, xx, yy, canvas.width*canvasScale, canvas.height*canvasScale);
  }
  
  private void displayCodeEditor() {
    // Update scroll for code pane
    boolean inCodePane = input.mouseX() >= middle();
    if (inCodePane) {
      if (inCanvasPane) {
        inCanvasPane = false;
        // We need to switch to our scroll value for the code scroll
        canvasPaneScroll   = input.scrollOffset;     
        input.scrollOffset = codePaneScroll;
      }
      
      if (input.primaryClick) {
        lastSelectedPane = CODE_PANE;
      }
      
      input.processScroll(0., max(getTextHeight(code)-(HEIGHT-myUpperBarWeight-myLowerBarWeight), 0));
    }
    
    // Positioning of the text variables
    // Used to be a function in engine, moved it to here because complications with
    // scroll, don't care.
    float x = middle();
    float y = myUpperBarWeight;
    float wi = WIDTH-middle(); 
    float hi = HEIGHT-myUpperBarWeight-myLowerBarWeight;
    
    
    // TODO: I really wanna use our shaders to reduce shader-switching
    // instead of processing's shaders.
    app.resetShader();
    // Draw background
    app.fill(60);
    app.noStroke();
    app.rect(x, y, wi, hi);
    
    if (rendering) {
      // Use the same panel (code editor) for the rendering info.
    }
    // All of this is y'know... the actual code editor.
    else {
      // make sure code string is sync'd with keyboardmessage
      
      // BIG TODO: This is not the safest solution. Please fix.
      if (!menuShown() && !loading.get() && input.keyboardMessage.length() > 0) code = input.keyboardMessage;
      
      // This should really be in the displayCanvas code but it's more convenient to have it here for now.
      // Damn I'm really giving myself coding debt for adding shortcuts.
      //boolean shortcuts = input.keyActionOnce("playPause");
      //if (lastSelectedPane == CANVAS_PANE && shortcuts) {
      //  input.backspace();   // Don't want the unintended space.
      //}
      
      
      // ctrl+s save keystroke
      // Really got to fix this input.keys flaw thing.
      if (!input.altDown && input.ctrlDown && input.keys[int('s')] == 2) {
        saveScripts();
      }
      
      
      // Zoom in/out keys
      if (input.altDown && input.keys[int('=')] == 2) {
        textAreaZoom += 2.;
        input.backspace();
      }
      if (input.altDown && input.keys[int('-')] == 2) {
        textAreaZoom -= 2.;
        input.backspace();
      }
      
      // Scroll slightly when some y added to text.
      if (input.enterOnce) {
        if (getTextHeight(code) > (HEIGHT-myUpperBarWeight-myLowerBarWeight) && inCodePane) {
          input.scrollOffset -= (textAreaZoom);  // Literally just a random char
        }
      }
      
      // Slight position offset
      x += 5;
      y += 5;
        
      // Prepare font
      app.fill(255);
      app.textAlign(LEFT, TOP);
      app.textFont(display.getFont("Source Code"), textAreaZoom);
      app.textLeading(textAreaZoom);
      
      // Scrolling (make sure to keep in account the whole mouse-in-left-or-right pane thing
      // (god my code is so messy)
      float scroll = input.scrollOffset;
      if (!inCodePane) {
        scroll = codePaneScroll;
      }
      
      // Display text
      if (!menuShown()) {
        app.text(input.keyboardMessageDisplay(code), x, y+scroll);
      }
      else {
        app.text(code, x, y+scroll);
      }
    }
  }
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  /////////////////////////////////////// 
  // MENU
  
  TextField widthField  = new TextField("config-width", "Width: ");
  TextField heightField = new TextField("config-height", "Height: ");
  TextField timeLengthField = new TextField("config-timelength", "Video length: ");
  TextField framerateField = new TextField("render-framerate", "Framerate: ");
  private boolean smoothChangesMade = false;
  public void displayMenu() {
    if (menuShown()) {
      // Bug fix to prevent sprite being selected as we click the menu.
      if (!loading.get()) sprites.selectedSprite = null;
    }
    
    //////////////////
    // CONFIG MENU
    //////////////////
    if (configMenu) {
      
      // Background
      gui.sprite("config-back-1", "black");
      
      // Title
      textSprite("config-menu-title", "--- Sketch config ---");
      
      
      
      app.fill(255);
      
      // Width field
      widthField.display();
      
      // Height field
      heightField.display();
      
      // Time length field
      timeLengthField.display();
      // Lil button next to timelength field to sync time to music
      if (ui.button("config-syncmusictime", "music_time_128", "")) {
        selectedField = null;
        sound.playSound("select_any");
        timeLengthField.value = str(sound.getCurrentMusicDuration());
        //try {
        //  String musicPath = sketchiePath+"music/"+selectedMusic;
        //  if (selectedMusic.length() > 0 && file.exists(musicPath)) {
        //    Movie music = new Movie(app, musicPath);
        //    music.read();
        //    timeLengthField.value = str(music.duration());
        //  }
        //}
        //catch (RuntimeException e) {
        //  console.warn("Sound duration get failed. "+e.getMessage());
        //}
      }
      
      // Anti-aliasing field
      String smoothDisp = "Anti-aliasing: ";
      switch (canvasSmooth) {
        case 0:
        smoothDisp += "None (pixelated)";
        break;
        case 1:
        smoothDisp += "1x";
        break;
        case 2:
        smoothDisp += "2x";
        break;
        case 4:
        smoothDisp += "4x";
        break;
        case 8:
        smoothDisp += "8x";
        break;
      }
      
      if (textSprite("config-smooth", smoothDisp) && !ui.miniMenuShown()) {
        String[] labels = new String[5];
        Runnable[] actions = new Runnable[5];
        
        labels[0] = "None (pixelated)";
        actions[0] = new Runnable() {public void run() { canvasSmooth = 0; smoothChangesMade = true; }};
        
        labels[1] = "1x anti-aliasing";
        actions[1] = new Runnable() {public void run() { canvasSmooth = 1; smoothChangesMade = true; }};
        
        labels[2] = "2x anti-aliasing";
        actions[2] = new Runnable() {public void run() { canvasSmooth = 2; smoothChangesMade = true; }};
        
        labels[3] = "4x anti-aliasing";
        actions[3] = new Runnable() {public void run() { canvasSmooth = 4; smoothChangesMade = true; }};
        
        labels[4] = "8x anti-aliasing";
        actions[4] = new Runnable() {public void run() { canvasSmooth = 8; smoothChangesMade = true; }};
        
        
        ui.createOptionsMenu(labels, actions);
      }
      
      
      String musicDisp = (musicFiles.length > 0 ? selectedMusic : "(no files available)");
      if (selectedMusic.length() == 0) musicDisp = "(None)";
      if (textSprite("config-music", "Music: "+musicDisp) && !ui.miniMenuShown()) {
        if (musicFiles.length > 0) {
          String[] labels = new String[musicFiles.length+1];
          Runnable[] actions = new Runnable[musicFiles.length+1];
          
          // None option
          labels[0] = "(None)";
          actions[0] = new Runnable() {public void run() { selectedMusic = ""; }};
          
          for (int i = 0; i < musicFiles.length; i++) {
            final int index = i;
            labels[i+1]  = musicFiles[i];
            actions[i+1] = new Runnable() {
              public void run() { 
                selectedMusic = musicFiles[index]; 
                setMusic(selectedMusic);
              }
            };
          }
          
          ui.createOptionsMenu(labels, actions);
        }
      }
      
      // Cross button
      if (ui.button("config-cross-1", "cross", "")) {
        sound.playSound("select_smaller");
        input.keyboardMessage = code;
        configMenu = false;
      }
      
      // Apply button
      if (ui.button("config-ok", "tick_128", "Apply")) {
        sound.playSound("select_any");
        time = 0.;
        
        try {
          int wi = Integer.parseInt(widthField.value);
          int hi = Integer.parseInt(heightField.value);
          timeLength = Float.parseFloat(timeLengthField.value)*60.;
          
          // Only recreate if changes have been made.
          if (wi != (int)canvas.width ||
              hi != (int)canvas.height ||
              smoothChangesMade
          ) {
            createCanvas(wi, hi, canvasSmooth);
          }
        }
        catch (NumberFormatException e) {
          console.log("Invalid inputs!");
          return;
        }
        //setMusic(selectedMusic);
        
        
        saveConfig();
        
        // End
        input.keyboardMessage = code;
        configMenu = false;
      }
    }
    
    
    /////////////////////
    // RENDER MENU
    /////////////////////
    else if (renderMenu) {
      
      // Background
      gui.sprite("render-back-1", "black");
      
      // Title
      textSprite("render-menu-title", "--- Render ---");
      
      // Framerate field
      framerateField.display();
      
      // That massive block below is indeed the
      // compression field.
      String compressionDisp = "Compression: "+renderFormat;
      if (textSprite("render-compression", compressionDisp) && !ui.miniMenuShown()) {
        String[] labels = new String[6];
        Runnable[] actions = new Runnable[6];
        
        labels[0] = "MPEG-4";
        actions[0] = new Runnable() {public void run() { renderFormat = labels[0]; }};
        
        labels[1] = "MPEG-4 (Lossless 4:2:0)";
        actions[1] = new Runnable() {public void run() { renderFormat = labels[1]; }};
        
        labels[2] = "MPEG-4 (Lossless (4:4:4)";
        actions[2] = new Runnable() {public void run() { renderFormat = labels[2]; }};
        
        labels[3] = "Apple ProRes 4444";
        actions[3] = new Runnable() {public void run() { renderFormat = labels[3]; }};
        
        labels[4] = "Animated GIF";
        actions[4] = new Runnable() {public void run() { renderFormat = labels[4]; }};
        
        labels[5] = "Animated GIF (Loop)";
        actions[5] = new Runnable() {public void run() { renderFormat = labels[5]; }};
        
        ui.createOptionsMenu(labels, actions);
      }
      
      // Pixel upscale field
      String upscaleDisp = "Pixel upscale: "+int(upscalePixels*100.)+"% "+(upscalePixels == 1. ? "(None)" : "");
      
      if (textSprite("render-upscale", upscaleDisp) && !ui.miniMenuShown()) {
        String[] labels = new String[6];
        Runnable[] actions = new Runnable[6];
        
        labels[0] = "25%";
        actions[0] = new Runnable() {public void run() { upscalePixels = 0.25; }};
        
        labels[1] = "50%";
        actions[1] = new Runnable() {public void run() { upscalePixels = 0.5; }};
        
        labels[2] = "100% (None)";
        actions[2] = new Runnable() {public void run() { upscalePixels = 1.; }};
        
        labels[3] = "200%";
        actions[3] = new Runnable() {public void run() { upscalePixels = 2.; }};
        
        labels[4] = "300%";
        actions[4] = new Runnable() {public void run() { upscalePixels = 3.; }};
        
        labels[5] = "400%";
        actions[5] = new Runnable() {public void run() { upscalePixels = 4.; }};
        
        ui.createOptionsMenu(labels, actions);
      }
      
      
      // Start rendering button
      if (ui.button("render-ok", "tick_128", "Start rendering")) {
        sound.playSound("select_any");
        try {
          renderFramerate = Float.parseFloat(framerateField.value);
        }
        catch (NumberFormatException e) {
          console.log("Invalid inputs!");
          return;
        }
        
        beginRendering();
        input.keyboardMessage = code;
        renderMenu = false;
      }
      
      // Close menu button
      if (ui.button("render-cross-1", "cross", "")) {
        sound.playSound("select_smaller");
        input.keyboardMessage = code;
        renderMenu = false;
      }
    }
  }
  
  /////////////////////////////////////////////////
  // TEXT FIELD CLASS
  /////////////////////////////////////////////////
  TextField selectedField = null;
  class TextField {
    private String spriteName = "";
    public String value = "";
    private String labelDisplay = "";
    
    public TextField(String spriteName, String labelDisplay) {
      this.spriteName = spriteName;
      this.labelDisplay = labelDisplay;
    }
    
    public void display() {
      String disp = gui.interactable ? "white" : "nothing";
      if (selectedField == this) {
        gui.sprite(spriteName, disp);
        value = input.keyboardMessage;
      }
      else {
        if (ui.button(spriteName, disp, "")) {
          selectedField = this;
          input.keyboardMessage = value;
          input.cursorX = input.keyboardMessage.length();
        }
      }
      
      float x = gui.getSprite(spriteName).getX();
      float y = gui.getSprite(spriteName).getY();
      
      
      app.textAlign(LEFT, TOP);
      app.textSize(32);
      if (selectedField == this) {
        app.text(labelDisplay+input.keyboardMessageDisplay(value), x, y);
      }
      else {
        app.text(labelDisplay+value, x, y);
      }
    }
  }
  
  public boolean textSprite(String name, String val) {
    String disp = gui.interactable ? "white" : "nothing";
    boolean clicked = ui.button(name, disp, "");
    
    float x = gui.getSprite(name).getX();
    float y = gui.getSprite(name).getY();
    
    app.textAlign(LEFT, TOP);
    app.textSize(32);
    app.text(val, x, y);
    return clicked;
  }
  
  
  
  
  
  
  ///////////////////////////////////////////////
  // RENDERING
  
  private void beginRendering() {
    // Don't even bother if our code is not working
    if (!successful.get()) {
      console.log("Fix compilation errors before rendering!");
      return;
    }
    
    // Check frames folder
    // Using File class cus we need to make dir if it dont exist
    String framesPath = engine.APPPATH+"frames/";
    console.log(framesPath);
    File f = new File(framesPath);
    if (!f.exists()) {
      f.mkdir();
    }
    
    // Create our canvases (absolutely no scaling allowed)
    shaderCanvas = createGraphics(canvas.width, canvas.height, P2D);
    ((PGraphicsOpenGL)shaderCanvas).textureSampling(2);   // Disable texture smoothing
    
    if (upscalePixels != 1.) {
      scaleCanvas = createGraphics(int(canvas.width*upscalePixels), int(canvas.height*upscalePixels), P2D);
      ((PGraphicsOpenGL)scaleCanvas).textureSampling(2);   // Disable texture smoothing
    }
    
    // set our variables
    time = 0.0;
    renderFrameCount = 0;
    power.allowMinimizedMode = false;
    play();
    
    // Give a little bit of time so the UI can disappear for better user feedback.
    timeBeforeStartingRender = 5;
    
    // Now we begin.
    rendering = true;
  }
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  ///////////////////////////////////////////////////////
  // THE MOST IMPORTANT STUFF
  
  private void runCanvas() {
    // Display compilation status
    if (!compiling.get() && once.compareAndSet(true, false)) {
      if (!successful.get()) {
        console.log(plugin.errorOutput);
        pause();
      }
      else {
        console.log("Successful compilation!");
        play();
        time = 0.;
      }
    }
    
    // Need to use the right sprite system
    ui.useSpriteSystem(sprites);
    sprites.interactable = !menuShown();
    
    // Use our custom delta funciton (which force sets it to the correct value while rendering)
    sprites.setDelta(getDelta());
    
    // Switch canvas, then begin running the plugin code
    if (successful.get() && !compiling.get() && !loading.get()) {
      canvas.beginDraw();
      canvas.fill(255, 255);
      display.setPGraphics(canvas);
      plugin.run();
      canvas.endDraw();
    }
    sprites.updateSpriteSystem();
    display.setPGraphics(app.g);
    
    // This is simply to allow a few frames for the UI to disappear for user feedback.
    // We skip rendering if true here.
    if (rendering && timeBeforeStartingRender > 0) {
      timeBeforeStartingRender--;
      if (timeBeforeStartingRender == 3) {
        // Delete all files that may be in this folder
        File[] leftoverFiles = (new File(engine.APPPATH+"frames/")).listFiles();
        if (leftoverFiles != null) {
          for (File ff : leftoverFiles) {
            ff.delete();
          }
        }
      }
      time = 0.;
      return;
    }
    
    // The actual part where we render our animation
    if (rendering && !converting && successful.get() && !compiling.get()) {
      // This path has already been created so it will DEFO work
      String frame = engine.APPPATH+"frames/"+nf(renderFrameCount++, 6, 0)+".tiff";
      
      // Do shader stuff (TODO later)
      // And another TODO: optimise, if we don't have any shaders,
      // save directly from canvas instead (big performance saves!)
      shaderCanvas.beginDraw();
      shaderCanvas.clear();
      shaderCanvas.image(canvas, 0, 0, shaderCanvas.width, shaderCanvas.height);
      shaderCanvas.endDraw();
      
      // Do scaling (yay)
      // But if we don't have scaling enabled skip this step, will save performance and time.
      if (upscalePixels != 1) {
        scaleCanvas.beginDraw();
        scaleCanvas.clear();
        scaleCanvas.image(shaderCanvas, 0, 0, scaleCanvas.width, scaleCanvas.height);
        scaleCanvas.endDraw();
        scaleCanvas.save(frame);
      }
      else {
        // If scaling is disabled, then shading canvas already has everything we need.
        shaderCanvas.save(frame);
      }
      
    }
    
    // Update time
    if (playing) {
      time += getDelta();
      
      // When we reach the end of the animation
      if (time > timeLength) {
        if (rendering) {
          pause();
          beginConversion();
          
          // TODO: open output file
        }
        else {
          // Restart if looping, stop playing if not
          if (!loop) pause();
          else time = 0.;
        }
      }
    }
  }
  
  public void content() {
    power.setAwake();
    
    // Set engine typing settings.
    input.addNewlineWhenEnterPressed = codeEditorShown;
    engine.allowShowCommandPrompt = !codeEditorShown;
    
    if (!loading.get()) {
      if (processAfterLoadingIndex.get() > 0) {
        int i = processAfterLoadingIndex.decrementAndGet();
        
        // Create large image, I don't want the lag
        // TODO: option to select large image or normal pimage.
        LargeImage largeimg = display.createLargeImage(loadedImages.get(i));
        
        
        // Add to systemimages so we can use it in our sprites
        display.systemImages.put(imagesInSketch.get(i), new DImage(largeimg, loadedImages.get(i)));
        
        if (i == 0) {
          if (configJSON != null) {
            canvasSmooth = configJSON.getInt("smooth", 1);
            createCanvas(configJSON.getInt("canvas_width", 1024), configJSON.getInt("canvas_height", 1024), canvasSmooth);
            setMusic(selectedMusic);
          }
          
          
          input.keyboardMessage = code;
          input.cursorX = code.length();
          compileCode(code);
        }
      }
      
      runCanvas();
      displayCanvas();
      
      if (codeEditorShown()) {
        displayCodeEditor();
      }
      
      if (!input.primaryDown) {
        selectedPane = 0;
      }
      
      // we "stop" the music by simply muting the audio, in the background it's still playing tho,
      // but it makes coding a lot more simple.
      if (playing && !rendering) {
        //sound.setMusicVolume(musicVolume);
        sound.syncMusic(time/60.);
      }
      else {
        //sound.setMusicVolume(0.);
      }
      
    }
    else {
      ui.loadingIcon(WIDTH/4, HEIGHT/2);
      app.textFont(engine.DEFAULT_FONT, 32);
      app.fill(255);
      app.textAlign(CENTER, TOP);
      app.text("Loading...", WIDTH/4, HEIGHT/2+128);
    }
  }
  
  
  public void upperBar() {
    display.shader("fabric", "color", 0.43,0.4,0.42,1., "intensity", 0.1);
    super.upperBar();
    app.resetShader();
    ui.useSpriteSystem(gui);
    
    // Display UI for rendering
    if (rendering) {
      // We have one for stage 1 and stage 2
      if (!converting) {
        ui.loadingIcon(WIDTH*0.75, HEIGHT/2);
        textSprite("renderinginfoscreen-txt1", "Rendering sketch...\nStage 1/2");
        if (ui.button("renderinginfoscreen-cancel", "cross_128", "Stop rendering")) {
          sound.playSound("select_smaller");
          pause();
          rendering = false;
          power.allowMinimizedMode = true;
          console.log("Rendering cancelled.");
        }
      }
      else {
        ui.loadingIcon(WIDTH*0.75, HEIGHT/2);
        textSprite("renderinginfoscreen-txt1", 
        "Converting to "+renderFormat+"...\n"+
        "Stage 2/2\n"+
        "("+ffmpeg.framecount+"/"+renderFrameCount+")");
        
        // Finish rendering
        //if (ffmpeg.framecount >= renderFrameCount) {
        //}
        
        // TODO: progress bar?
      }
    }
    
    if (!menuShown()) {
      if (ui.button("compile_button", "media_128", "Compile")) {
        // Don't allow to compile if it's already compiling
        // (cus we gonna end up with threading issues!)
        if (!compiling.get()) {
          sound.playSound("select_any");
          // If not showing code editor, we are most likely using an external ide to program this.
          // So do not save what we have in memory.
          if (codeEditorShown) {
            saveScripts();
          }
          compileCode(loadScript());
        } 
      }
      
      if (ui.button("showcode_button", "code_128", codeEditorShown ? "Hide code" : "Show code")) {
        sound.playSound("select_any");
        codeEditorShown = !codeEditorShown;
        saveConfig();
      }
      
      if (ui.button("settings_button", "doc_128", "Sketch config")) {
        sound.playSound("select_any");
        widthField.value = str(canvas.width);
        heightField.value = str(canvas.height);
        timeLengthField.value = str(timeLength/60.);
        selectedField = null;
        configMenu = true;
        input.keyboardMessage = "";
      }
      
      if (ui.button("render_button", "image_128", "Render")) {
        sound.playSound("select_any");
        selectedField = null;
        framerateField.value = "60";
        renderMenu = true;
        input.keyboardMessage = "";
      }
      
      if (ui.button("folder_button", "folder_128", "Show files")) {
        sound.playSound("select_any");
        pause();
        file.open(sketchiePath);
      }
      
      if (ui.button("back_button", "back_arrow_128", "Explorer")) {
        sound.playSound("select_any");
        sound.stopMusic();
        
        // TODO: really need some sort of file change detection instead of relying on the
        // editor being hidden to know whether or not we have an outdated version in memory.
        if (codeEditorShown) {
          saveScripts();
          sound.playSound("chime");
        }
        previousScreen();
      }
      
      if (compiling.get()) {
        ui.loadingIcon(WIDTH-64-10, myUpperBarWeight+64+10, 128);
      }
    }
    else {
      displayMenu();
    }
    
    gui.updateSpriteSystem();
  }
  
  private boolean selectedPaneTimeline() {
    return !rendering && (selectedPane == 0 || selectedPane == TIMELINE_PANE);
  }
  
  public void lowerBar() {
    //display.shader("fabric", "color", 0.43,0.4,0.42,1., "intensity", 0.1);
    myLowerBarColor = color(78, 73, 73);
    super.lowerBar();
    app.resetShader();
    
    float BAR_X_START = 70.;
    float BAR_X_LENGTH = WIDTH-120.-BAR_X_START;
    
    // Display timeline
    float y = HEIGHT-myLowerBarWeight;
    app.fill(50);
    app.noStroke();
    app.rect(BAR_X_START, y+(myLowerBarWeight/2)-2, BAR_X_LENGTH, 4);
    
    float percent = time/timeLength;
    float timeNotchPos = BAR_X_START+BAR_X_LENGTH*percent;
    
    app.fill(255);
    app.rect(timeNotchPos-4, y+(myLowerBarWeight/2)-25, 8, 50); 
    
    display.imgCentre(playing ? "pause_128" : "play_128", BAR_X_START/2, y+(myLowerBarWeight/2), myLowerBarWeight, myLowerBarWeight);
    
    if ((input.mouseY() > y || selectedPane == TIMELINE_PANE) && !ui.miniMenuShown()) {
      if (input.mouseX() > BAR_X_START) {
        // If in bar zone
        if (input.primaryDown && selectedPaneTimeline()) {
          float notchPercent = min(max((input.mouseX()-BAR_X_START)/BAR_X_LENGTH, 0.), 1.);
          time = timeLength*notchPercent;
        }
        
        // Messy code over there so it only acts once
        if (input.primaryClick) {
          selectedPane = TIMELINE_PANE;
        }
      }
      else {
        // If in play button area
        if (input.primaryClick && selectedPaneTimeline()) {
          // Toggle play/pause button
          togglePlay();
          // Restart if at end
          if (playing && time > timeLength) time = 0.;
        }
        // Right click action to show minimenu
        else if (input.secondaryClick && selectedPaneTimeline()) {
          String[] labels = new String[1];
          Runnable[] actions = new Runnable[1];
          
          labels[0] = loop ? "Disable loop" : "Enable loop";
          actions[0] = new Runnable() {public void run() {
              loop = !loop;
          }};
          
          ui.createOptionsMenu(labels, actions);
        }
      }
    }
  }
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  /////////////////////////////////////////////////
  // FFMPEG STUFF
  // (mostly stolen from MovieMaker source code lol
  
  
  // Literally copy+pasted straight from processing code.
  void createMovie(String path, String soundFilePath, String imgFolderPath, final int wi, final int hi, final double fps, final String formatName) {
    final File movieFile = new File(path);
  
    // ---------------------------------
    // Check input
    // ---------------------------------
    final File soundFile = soundFilePath.trim().length() == 0 ? null : new File(soundFilePath.trim());
    final File imageFolder = imgFolderPath.trim().length() == 0 ? null : new File(imgFolderPath.trim());
    if (soundFile == null && imageFolder == null) {
      timewayEngine.console.bugWarn("createMovie: Need soundFile imageFolder input");
      return;
    }
  
    if (wi < 1 || hi < 1 || fps < 1) {
      timewayEngine.console.bugWarn("createMovie: bad numbers");
      return;
    }
  
    // ---------------------------------
    // Create the QuickTime movie
    // ---------------------------------
    new SwingWorker<Throwable, Object>() {
  
      @Override
      protected Throwable doInBackground() {
        try {
          // Read image files
          File[] imgFiles;
          if (imageFolder != null) {
            imgFiles = imageFolder.listFiles(new FileFilter() {
              final FileSystemView fsv = FileSystemView.getFileSystemView();
  
              public boolean accept(File f) {
                return f.isFile() && !fsv.isHiddenFile(f) &&
                  !f.getName().equals("Thumbs.db");
              }
            });
            if (imgFiles == null || imgFiles.length == 0) {
              timewayEngine.console.bugWarn("createMovie: no images found");
            }
            Arrays.sort(imgFiles);
  
            // Delete movie file if it already exists.
            if (movieFile.exists()) {
              if (!movieFile.delete()) {
                return new RuntimeException("Could not replace " + movieFile.getAbsolutePath());
              }
            }
  
            ffmpeg.write(movieFile, imgFiles, soundFile, wi, hi, fps, formatName);
          }
          return null;
  
        } catch (Throwable t) {
          return t;
        }
      }
  
      @Override
      protected void done() {
        Throwable t;
        try {
          t = get();
        } catch (Exception ex) {
          t = ex;
        }
        if (t != null) {
          t.printStackTrace();
          console.warn("createMovie: Failed to create movie, sorry");
        }
        else {
          console.log("Done render!");
          
          // Show the file in file explorer
          file.open(engine.APPPATH+"output/");
        }
        
        rendering = false;
        converting = false;
        power.allowMinimizedMode = true;
      }
    }.execute();
  
  }
  
  
  // Calls our cool and totally not stolen createMovie function
  // and runs ffmpeg
  private void beginConversion() {
    int wi = canvas.width;
    int hi = canvas.height;
    if (upscalePixels != 1.) {
      wi = scaleCanvas.width;
      hi = scaleCanvas.height;
    }
    
    // create output folder if it don't exist.
    String outputFolder = engine.APPPATH+"output/";
    
    int outIndex = 1;
    // Note that files are named as:
    // 0001.mp4
    // 0002.mp4
    // 0003.gif
    // etc
    // This is so we can save our animation without
    // replacing any files that may already exist in this folder.
    
    File f = new File(outputFolder);
    if (!f.exists()) {
      f.mkdir();
    }
    else {
      File[] files = f.listFiles();
      // Find the highest number count.
      int highest = 0;
      for (File ff : files) {
        // Not to worry if it's a string like "aaa", processing's
        // int() just returns 0 if that's the case.
        int num = int(file.getIsolatedFilename(ff.getName()));
        if (num > highest) {
          highest = num;
        }
      }
      // Now we have the highest
      outIndex = highest+1;
    }
    
    // Annnnnd the extension
    String ext = ".mp4";
    if (renderFormat.contains("GIF")) ext = ".gif";
    else if (renderFormat.contains("Apple")) ext = ".mov";
    
    converting = true;
    ffmpeg.framecount = 0;
    
    // Include music
    String musicPath = sketchiePath+"music/"+selectedMusic;
    if (!file.exists(musicPath)) {
      musicPath = "";
    }
    createMovie(outputFolder+nf(outIndex, 4, 0)+ext, musicPath, engine.APPPATH+"frames/", wi, hi, (double)renderFramerate, renderFormat);
  }
  
  
  
  
  
  //////////////////////////////////////
  // FINALIZATION
  
  public void finalize() {
    //free();
  }
  
  public void free() {
     // Clear the images from systemimages to clear up used images.
     for (String s : imagesInSketch) {
       display.systemImages.remove(s);
     }
     imagesInSketch.clear();
  }
}
