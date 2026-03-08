import java.util.Locale;

/**
 * Sistema de N partícules (N=2 o 3) amb gravetat newtoniana en 2D
 * Integrador: Velocity-Verlet (leapfrog)
 * Controls:
 *   [espai] pausa/reprèn
 *   [i]     reinicia amb condicions inicials definides a dalt
 *   [n]     estat aleatori amb P_total = 0
 *   [t]     activa/desactiva rastre
 *   [c]     captura estat actual com a noves condicions inicials (memòria)
 *   [s]     desa condicions inicials a fitxer (IC.json)
 *   [l]     carrega condicions inicials de fitxer (IC.json)
 *   [e]     exporta x(t) a TSV (x_t_export.tsv)
 * A més, s’enregistra AUTOMÀTICAMENT tota la trajectòria a un TSV amb timestamp.
 */

/* =================== CONFIGURACIÓ =================== */

// Nombre de partícules actiu: 2 o 3
int N = 2;

// Masses inicials
float[] masses = {
  15000.0,   // m0
  5.0,      // m1
  0.05     // m2 (si N=2, s'ignora el tercer)
};

// Posicions inicials (relatives al centre)
PVector[] pos_init = {
  new PVector(0, 0),
  new PVector(400, 0),
  new PVector(405, 0)
};

// Velocitats inicials (px/frame)
PVector[] vel_init = {
  new PVector(0, 0.0),
  new PVector(0, 79.1),  
  new PVector(0, 79.1+30)
};

// Velocitats base (per escalar amb sliders)
PVector[] base_vel_init = {
  new PVector(0, 0.0),
  new PVector(0, 329.0),
  new PVector(0, 79.1+30)
};

/* =================== PARÀMETRES SIMULACIÓ =================== */

Particle[] P = new Particle[N];

float G = 1000f;
float dt = 0.001f;
float dtBase = 0.001f;
float dtMinDyn = 0.00001f;
boolean adaptiveDt = true;
float dtAdaptStart = 120f;   // velocitat a partir de la qual es redueix dt
float dtAdaptK = 0.004f;     // força de reducció
float dtFloorFrac = 0.35f;   // límit inferior relatiu a dtBase
float softening = 4f;
float soft2 = softening*softening;

boolean paused = false;
boolean trailsOn = true;
PGraphics trails;
PFont uiFont;
TwoPosSwitch resSwitch;
boolean useEuler = false;
boolean showPolarVectors = true;
boolean showAxes = true;

// gràfic x(t)
int graphHeight = 110;
int graphMargin = 12;
int graphWidth;
float[][] xHist;     // xHist[i][k]
float[]   tHist;     // temps corresponent a cada mostra
float[]   yHist;     // y(t) per a m1
float[] rHist;       // r(t) per a m1
float[] thetaHist;   // theta(t) per a m1
float[] vrHist;      // v_r(t) per a m1
float[] vtHist;      // v_t(t) per a m1
float[] arHist;      // a_r(t) per a m1
float[] atHist;      // a_t(t) per a m1
int histSize;
int histIndex = 0;
float timeNow = 0;
float plotTimeWindow = 10.0f;
int plotEvery = 4; // mostra una de cada N frames calculats
int plotEveryMin = 1;
int plotEveryMax = 20;
int plotCounter = 0;
int graphRenderEvery = 4; // refresca plots cada N frames de render
PImage plotsCache = null;
boolean plotsCacheValid = false;
int plotsCacheX = 0;
int plotsCacheY = 0;
int plotsCacheW = 0;
int plotsCacheH = 0;

/* =================== UI (BOTONS + SLIDERS) =================== */

int btnX = 12;
int btnY = 12;
int btnW = 110;
int btnH = 26;
int btnGap = 8;
int btnResetW = 90;
int btnResetH = 26;
int btnResetX = btnX + btnW + 12;
int btnResetY = btnY;
int btnShotW = 110;
int btnShotH = 26;
int btnShotX = btnResetX;
int btnShotY = btnResetY + btnResetH + btnGap;

int sliderX = 12;
int sliderY = btnY + 2*(btnH+btnGap) + 10;
int sliderW = 420;
int sliderH = 16;
int sliderGap = 10;

boolean lowResMode = false;
int configuredPixelDensity = 1;
float viewScale = 1.0f;
float viewScaleMin = 0.20f;
float viewScaleMax = 3.00f;

float distScale = 1.0f;
float Gmin = 10f;
float Gmax = 5000f;
float[] velScale = {0.0f, 79.1f, 109.1f};
float dtMin = 0.0001f;
float dtMax = 0.01f;
float sliderLogMin = 0.01f;
float sliderLogMax = 1.0e7f;
int activeSlider = -1;
boolean draggingCentral = false;
PVector viewPan = new PVector(0, 0);

// valors base per escalar distancies
PVector[] base_pos_init = {
  new PVector(0, 0),
  new PVector(200, 0),
  new PVector(285, 0)
};

/* =================== LOG AUTOMÀTIC DE TRAJECTÒRIA =================== */

PrintWriter trajOut = null;
String trajFilename = "";
int flushEvery = 60;   // flush cada 60 frames aprox
int sinceLastFlush = 0;
boolean autoLog = false;

// formatador amb punt decimal
String f6(float v){ return String.format(Locale.US, "%.6f", v); }

/* =================== SETUP =================== */

void setup() {
  size(1500, 920);
  configuredPixelDensity = loadPixelDensityPreference();
  pixelDensity(configuredPixelDensity);
  lowResMode = (configuredPixelDensity == 1);
  noSmooth();
  uiFont = createFont("Monospaced", 12);
  resSwitch = new TwoPosSwitch(btnResetX + btnResetW + 18, btnY + 5, 74, 16, lowResMode, "Alta", "Baixa");
  trails = createGraphics(width, height);
  resetTrails();

  clampArraysToN();      // assegura que masses/pos_init/vel_init tenen almenys N entrades
  applyDistanceScale();
  applyVelocityScale();
  initFromTop();
  computeAccelerations();

  graphWidth = sliderW;
  histSize = max(200, (graphWidth - 2*graphMargin) * 2);
  xHist = new float[N][histSize];
  tHist = new float[histSize];
  allocPolarHist();
  resetGraph();

  // Log automàtic desactivat
}

/* =================== DRAW =================== */

void draw() {
  if (!paused) {
    if (adaptiveDt) {
      float vref = (N > 1) ? P[1].vel.mag() : 0;
      float over = max(0, vref - dtAdaptStart);
      float dyn = 1.0 + dtAdaptK * over;
      float dtFloor = max(dtMinDyn, dtBase * dtFloorFrac);
      dt = max(dtFloor, dtBase / dyn);
    } else {
      dt = dtBase;
    }
    if (useEuler) stepEuler(dt);
    else stepVerlet(dt);
    timeNow += dt;
    if (trailsOn) {
      trails.beginDraw();
      float trailStroke = constrain(1.6f / max(viewScale, 1e-6f), 0.15f, 12.0f);
      trails.strokeWeight(trailStroke);
      for (int i=0;i<N;i++) {
        trails.stroke(colorFor(i,150));
        trails.point(P[i].pos.x,P[i].pos.y);
      }
      trails.endDraw();
    }
    // historial per als gràfics (mostreig cada plotEvery passos de simulació)
    plotCounter++;
    if (plotCounter >= max(1, plotEvery)) {
      plotCounter = 0;
      int idx = histIndex % histSize;
      for (int i=0;i<N;i++) xHist[i][idx] = P[i].pos.x;
      tHist[idx] = timeNow;
      recordPolarHistory(idx);
      histIndex++;
    }

    // ---- REGISTRE AUTOMÀTIC A TSV: desactivat
  }

  background(10);
  PVector cm = centerOfMass();
  PVector focus = PVector.add(cm, viewPan);
  pushMatrix();
  applyViewTransform(focus);
  image(trails, 0, 0);
  popMatrix();

  // partícules
  for (int i=0;i<N;i++) {
    PVector pScreen = worldToScreen(P[i].pos, focus);
    P[i].drawBodyAt(pScreen, colorFor(i,255));
  }

  // vectors radial i transversal (m1)
  if (showPolarVectors) drawPolarVelocityVectors(cm, focus);

  // centre de masses sempre superposat
  PVector cmScreen = worldToScreen(cm, focus);
  stroke(240,240,80);
  strokeWeight(2.0f);
  float c = 6;
  line(cmScreen.x - c, cmScreen.y, cmScreen.x + c, cmScreen.y);
  line(cmScreen.x, cmScreen.y - c, cmScreen.x, cmScreen.y + c);
  stroke(20);
  strokeWeight(1.0f);
  line(cmScreen.x - c, cmScreen.y, cmScreen.x + c, cmScreen.y);
  line(cmScreen.x, cmScreen.y - c, cmScreen.x, cmScreen.y + c);
  noStroke();

  // energies
  float KE=0, PE=0;
  for (int i=0;i<N;i++) KE += 0.5*P[i].m*P[i].vel.magSq();
  for (int i=0;i<N;i++) for (int j=i+1;j<N;j++) {
    float rij = PVector.dist(P[i].pos,P[j].pos);
    PE += -G*P[i].m*P[j].m/sqrt(rij*rij+soft2);
  }
  float E=KE+PE;
  fill(255);
  textFont(uiFont);
  drawTopRightLabels(KE, PE, E);

  if (showAxes) drawReferenceAxes(cmScreen);
  drawButtons();
  drawSliders();

  // gràfics (cachejats per rendiment)
  drawAllGraphsCached();
}

/* =================== TECLAT =================== */

void keyPressed() {
  if (key==' ') paused=!paused;
  else if (key=='v'||key=='V') { useEuler = !useEuler; }
  else if (key=='p'||key=='P') { showPolarVectors = !showPolarVectors; }
  else if (key=='a'||key=='A') { showAxes = !showAxes; }
  else if (key=='d'||key=='D') { adaptiveDt = !adaptiveDt; }
  else if (key=='t'||key=='T') { trailsOn=!trailsOn; if (!trailsOn) resetTrails(); }
  else if (key=='i'||key=='I') {
    initFromTop(); computeAccelerations(); resetTrails(); resetGraph(); timeNow=0;
    recordInitialSample();
    // log automàtic desactivat
  } else if (key=='n'||key=='N') {
    initRandom();  computeAccelerations(); resetTrails(); resetGraph(); timeNow=0;
    recordInitialSample();
    // log automàtic desactivat
  } else if (key=='c'||key=='C') {
    captureCurrentAsInitials(); // sense fitxer
  } else if (key=='s'||key=='S') {
    saveIC("IC.json");          // JSON
  } else if (key=='l'||key=='L') {
    loadIC("IC.json"); initFromTop(); computeAccelerations(); resetTrails(); resetGraph(); timeNow=0;
    recordInitialSample();
    // log automàtic desactivat
  } else if (key=='e'||key=='E') {
    exportXTSV("x_t_export.tsv"); // export opcional del buffer x(t)
  }
}

/* =================== RATOLI =================== */

void mousePressed() {
  if (hitButton(btnX, btnY, btnW, btnH)) {
    setN(2);
  } else if (hitButton(btnX, btnY + btnH + btnGap, btnW, btnH)) {
    setN(3);
  } else if (hitButton(btnResetX, btnResetY, btnResetW, btnResetH)) {
    resetSimulation();
  } else if (hitButton(btnShotX, btnShotY, btnShotW, btnShotH)) {
    saveScreenshotPNG();
  } else if (resSwitch != null && resSwitch.hit(mouseX, mouseY)) {
    boolean prev = resSwitch.lowMode;
    resSwitch.mousePressed(mouseX, mouseY);
    if (resSwitch.lowMode != prev) {
      lowResMode = resSwitch.lowMode;
      savePixelDensityPreference(lowResMode ? 1 : displayDensity());
      println("Canvi de pixelDensity guardat. Reiniciant sketch...");
      exit();
    }
  } else if (hitCenterOfMass(mouseX, mouseY) || hitLargestMass(mouseX, mouseY)) {
    draggingCentral = true;
    dragCenterOfMassTo(mouseX, mouseY);
  } else {
    int s = hitAnySlider();
    if (s >= 0) {
      activeSlider = s;
      updateSliderValue(activeSlider, mouseX);
    }
  }
}

void mouseDragged() {
  if (draggingCentral) {
    dragCenterOfMassTo(mouseX, mouseY);
  } else if (activeSlider >= 0) {
    updateSliderValue(activeSlider, mouseX);
  }
}

void mouseReleased() {
  if (draggingCentral) {
    draggingCentral = false;
    return;
  }
  if (activeSlider == 2*N) {
    resetTrails();
    resetGraph();
    timeNow = 0;
    openTrajectoryWriter("init");
  }
  activeSlider = -1;
}

/* =================== INICIALITZACIONS =================== */

void initFromTop() {
  PVector C=new PVector(width*0.5+250,height*0.5);
  for (int i=0;i<N;i++) {
    PVector pos = PVector.add(C,pos_init[i]);
    PVector vel = vel_init[i].copy();
    P[i] = new Particle(masses[i],pos,vel);
  }
  // centra CM i anul·la moment total
  PVector cm=centerOfMass();
  PVector shift=PVector.sub(C,cm);
  for (int i=0;i<N;i++) P[i].pos.add(shift);
  PVector Ptot=totalMomentum();
  float Mtot=0; for (int i=0;i<N;i++) Mtot+=masses[i];
  PVector vcm=PVector.div(Ptot,Mtot);
  for (int i=0;i<N;i++) P[i].vel.sub(vcm);
}

void initRandom() {
  for (int i=0;i<N;i++) {
    float m = random(1.5,4.0);
    PVector pos=new PVector(width*0.5+random(-280,280),height*0.5+random(-180,180));
    PVector vel=PVector.random2D().mult(random(0.0,1.2));
    P[i]=new Particle(m,pos,vel);
  }
  PVector cm=centerOfMass();
  PVector shift=PVector.sub(new PVector(width*0.5,height*0.5),cm);
  for (int i=0;i<N;i++) P[i].pos.add(shift);
  PVector Ptot=totalMomentum();
  float Mtot=0; for (int i=0;i<N;i++) Mtot+=P[i].m;
  PVector vcm=PVector.div(Ptot,Mtot);
  for (int i=0;i<N;i++) P[i].vel.sub(vcm);
}

void setN(int newN) {
  newN = constrain(newN, 2, 3);
  if (newN == N) return;
  N = newN;
  clampArraysToN();
  applyDistanceScale();
  applyVelocityScale();
  P = new Particle[N];
  xHist = new float[N][histSize];
  allocPolarHist();
  resetGraph();
  resetSimulation();
}

void resetSimulation() {
  paused = false; // RESET sempre reprèn la simulació
  initFromTop();
  computeAccelerations();
  resetTrails();
  resetGraph();
  timeNow = 0;
  recordInitialSample();
  // log automàtic desactivat
}

/* =================== DINÀMICA =================== */

void computeAccelerations() {
  for (int i=0;i<N;i++) P[i].acc.set(0,0);
  for (int i=0;i<N;i++) for (int j=i+1;j<N;j++) {
    PVector rij=PVector.sub(P[j].pos,P[i].pos);
    float r2=rij.magSq()+soft2;
    float invR=1.0/sqrt(r2);
    float invR3=invR*invR*invR;
    PVector a_i=PVector.mult(rij,G*P[j].m*invR3);
    PVector a_j=PVector.mult(rij,-G*P[i].m*invR3);
    P[i].acc.add(a_i);
    P[j].acc.add(a_j);
  }
}

void stepVerlet(float h) {
  for (int i=0;i<N;i++) P[i].vel.add(PVector.mult(P[i].acc,0.5*h));
  for (int i=0;i<N;i++) P[i].pos.add(PVector.mult(P[i].vel,h));
  computeAccelerations();
  for (int i=0;i<N;i++) P[i].vel.add(PVector.mult(P[i].acc,0.5*h));
}

void stepEuler(float h) {
  for (int i=0;i<N;i++) P[i].vel.add(PVector.mult(P[i].acc, h));
  for (int i=0;i<N;i++) P[i].pos.add(PVector.mult(P[i].vel, h));
  computeAccelerations();
}

/* =================== GRÀFIC x(t) =================== */

void resetGraph() {
  for (int i=0;i<N;i++) for (int k=0;k<histSize;k++) xHist[i][k]=Float.NaN;
  for (int k=0;k<histSize;k++) tHist[k]=Float.NaN;
  if (yHist != null) for (int k=0;k<histSize;k++) yHist[k]=Float.NaN;
  if (rHist != null) for (int k=0;k<histSize;k++) rHist[k]=Float.NaN;
  if (thetaHist != null) for (int k=0;k<histSize;k++) thetaHist[k]=Float.NaN;
  if (vrHist != null) for (int k=0;k<histSize;k++) vrHist[k]=Float.NaN;
  if (vtHist != null) for (int k=0;k<histSize;k++) vtHist[k]=Float.NaN;
  if (arHist != null) for (int k=0;k<histSize;k++) arHist[k]=Float.NaN;
  if (atHist != null) for (int k=0;k<histSize;k++) atHist[k]=Float.NaN;
  histIndex=0;
  plotCounter=0;
  invalidatePlotsCache();
}

void drawAllGraphs() {
  int gap = 10;
  int x = sliderX;
  int y = sliderY + sliderBlockHeight() + 32;
  int w = graphWidth;
  int h = graphHeight;

  drawDualTimePlot(x, y, w, h, xHist[1], yHist, "x(t), y(t)", "x(t)", "y(t)",
                   color(80, 200, 255), color(255, 170, 80), false);
  y += h + gap;
  drawDualTimePlot(x, y, w, h, rHist, thetaHist, "r(t), theta(t)", "r(t)", "theta(t)",
                   color(120, 220, 255), color(255, 200, 120), false);
  y += h + gap;
  drawDualTimePlot(x, y, w, h, vrHist, vtHist, "v_r(t), v_t(t)", "v_r(t)", "v_t(t)",
                   color(255, 140, 0), color(80, 220, 80), false);
  y += h + gap;
  drawDualTimePlot(x, y, w, h, arHist, atHist, "a_r(t), a_t(t)", "a_r(t)", "a_t(t)",
                   color(255, 90, 90), color(120, 200, 255), true);
}

void drawAllGraphsCached() {
  int gap = 10;
  int x0 = sliderX - 2;
  int y0 = sliderY + sliderBlockHeight() + 30;
  int w = graphWidth + 100;
  int h = 4 * graphHeight + 3 * gap + 20;

  x0 = max(0, x0);
  y0 = max(0, y0);
  w = max(1, min(width - x0, w));
  h = max(1, min(height - y0, h));

  boolean boundsChanged = (x0 != plotsCacheX || y0 != plotsCacheY || w != plotsCacheW || h != plotsCacheH);
  if (boundsChanged) {
    plotsCacheX = x0;
    plotsCacheY = y0;
    plotsCacheW = w;
    plotsCacheH = h;
    plotsCacheValid = false;
  }

  boolean refreshNow = !plotsCacheValid || (frameCount % max(1, graphRenderEvery) == 0);
  if (refreshNow) {
    drawAllGraphs();
    plotsCache = get(plotsCacheX, plotsCacheY, plotsCacheW, plotsCacheH);
    plotsCacheValid = (plotsCache != null);
  } else if (plotsCacheValid) {
    image(plotsCache, plotsCacheX, plotsCacheY);
  }
}

void invalidatePlotsCache() {
  plotsCacheValid = false;
}

int sliderBlockHeight() {
  int slidersCount = 2*N + 3; // masses + velocities + dist + G + dt
  return slidersCount * sliderH + (slidersCount - 1) * sliderGap;
}

void allocPolarHist() {
  yHist = new float[histSize];
  rHist = new float[histSize];
  thetaHist = new float[histSize];
  vrHist = new float[histSize];
  vtHist = new float[histSize];
  arHist = new float[histSize];
  atHist = new float[histSize];
}

void recordPolarHistory(int idx) {
  if (N < 2) return;
  int i = 1;
  PVector cm = centerOfMass();
  PVector vcm = centerOfMassVelocity();
  PVector acm = centerOfMassAcceleration();
  PVector r = PVector.sub(P[i].pos, cm);
  float rmag = max(r.mag(), 1e-6);
  PVector rhat = r.copy().div(rmag);
  PVector that = new PVector(-rhat.y, rhat.x);
  PVector vrel = PVector.sub(P[i].vel, vcm);
  PVector arel = PVector.sub(P[i].acc, acm);
  float vr = PVector.dot(vrel, rhat);
  float vt = PVector.dot(vrel, that);
  float ar = PVector.dot(arel, rhat);
  float at = PVector.dot(arel, that);
  rHist[idx] = rmag;
  thetaHist[idx] = atan2(r.y, r.x);
  vrHist[idx] = vr;
  vtHist[idx] = vt;
  yHist[idx] = P[i].pos.y;
  arHist[idx] = ar;
  atHist[idx] = at;
}

void recordInitialSample() {
  if (histSize <= 0) return;
  int idx = 0;
  for (int i=0;i<N;i++) xHist[i][idx] = P[i].pos.x;
  tHist[idx] = 0;
  recordPolarHistory(idx);
  histIndex = 1;
  plotCounter = 0;
}

void drawDualTimePlot(int gx, int gy, int gw, int gh,
                      float[] leftHist, float[] rightHist,
                      String title, String leftLabel, String rightLabel,
                      int leftCol, int rightCol, boolean symmetricRight) {
  float gwFrame = gw + 15;
  noStroke();
  fill(25);
  rect(gx, gy, gwFrame, gh, 10);

  boolean filled = histIndex >= histSize;
  int n = filled ? histSize : histIndex;
  int drawStride = max(1, plotEvery);
  if (n < 2) {
    fill(230);
    textSize(12);
    text(title+" (esperant dades...)", gx+10, gy+10);
    drawPanelFrame(gx, gy, gwFrame, gh);
    return;
  }

  float px0 = gx + plotPadL + plotFramePadX + plotShiftX;
  float px1 = gx + gwFrame - plotPadR - 24 - plotFramePadX + plotShiftX;
  float py0 = gy + plotPadT;
  float py1 = gy + gh - plotPadB;

  float tMin, tMax;
  float lMin = Float.POSITIVE_INFINITY, lMax = Float.NEGATIVE_INFINITY;
  float rMin = Float.POSITIVE_INFINITY, rMax = Float.NEGATIVE_INFINITY;
  tMin = 0;
  tMax = max(plotTimeWindow, timeNow);
  boolean hasLeft = false;
  boolean hasRight = false;
  for (int i=0;i<n;i+=drawStride) {
    int idx = filled ? (histIndex + i) % histSize : i;
    float tt = tHist[idx];
    float lv = leftHist[idx];
    float rv = rightHist[idx];
    if (Float.isNaN(tt) || tt > tMax) continue;
    if (!Float.isNaN(lv)) { lMin = min(lMin, lv); lMax = max(lMax, lv); hasLeft = true; }
    if (!Float.isNaN(rv)) { rMin = min(rMin, rv); rMax = max(rMax, rv); hasRight = true; }
  }
  if (!hasLeft) { lMin = -1; lMax = 1; }
  if (!hasRight) { rMin = -1; rMax = 1; }
  if (tMax - tMin < 1e-9) tMax = tMin + 1;
  if (lMax - lMin < 1e-9) { lMax = lMin + 1; lMin -= 1; }
  if (rMax - rMin < 1e-9) { rMax = rMin + 1; rMin -= 1; }
  if (symmetricRight) {
    float a = max(abs(rMin), abs(rMax));
    if (a < 1e-9) a = 1;
    rMin = -a;
    rMax = a;
  }

  strokeWeight(1);
  stroke(120);
  line(px0, py0, px0, py1);
  line(px1, py0, px1, py1);
  line(px0, py1, px1, py1);

  int xticks = 3;
  fill(230);
  textSize(10);
  for (int k=0;k<=xticks;k++) {
    float tt = lerp(tMin, tMax, k/(float)xticks);
    float x = map(tt, tMin, tMax, px0, px1);
    stroke(120);
    line(x, py1, x, py1+4);
    if (k % 2 == 0) {
      noStroke();
      textAlign(CENTER, TOP);
      text(fmtTick(tt, 1), x, py1+6);
    }
  }

  int yticks = 3;
  for (int k=0;k<=yticks;k++) {
    float val = lerp(lMin, lMax, k/(float)yticks);
    float y = map(val, lMax, lMin, py0, py1);
    stroke(120);
    line(px0-4, y, px0, y);
    if (k % 2 == 0) {
      noStroke();
      textAlign(RIGHT, CENTER);
      text(fmtTick(val, 2), px0-6, y);
    }
  }
  for (int k=0;k<=yticks;k++) {
    float val = lerp(rMin, rMax, k/(float)yticks);
    float y = map(val, rMax, rMin, py0, py1);
    stroke(120);
    line(px1, y, px1+4, y);
    if (k % 2 == 0) {
      noStroke();
      textAlign(LEFT, CENTER);
      text(fmtTick(val, 2), px1+6, y);
    }
  }
  textAlign(LEFT, BASELINE);

  stroke(leftCol);
  strokeWeight(0.9);
  noFill();
  beginShape();
  for (int i=0;i<n;i+=drawStride) {
    int idx = filled ? (histIndex + i) % histSize : i;
    float tt = tHist[idx];
    float lv = leftHist[idx];
    if (Float.isNaN(tt) || Float.isNaN(lv) || tt > tMax) continue;
    float x = map(tt, tMin, tMax, px0, px1);
    float y = map(lv, lMax, lMin, py0, py1);
    vertex(x, y);
  }
  endShape();

  stroke(rightCol);
  strokeWeight(0.9);
  noFill();
  beginShape();
  for (int i=0;i<n;i+=drawStride) {
    int idx = filled ? (histIndex + i) % histSize : i;
    float tt = tHist[idx];
    float rv = rightHist[idx];
    if (Float.isNaN(tt) || Float.isNaN(rv) || tt > tMax) continue;
    float x = map(tt, tMin, tMax, px0, px1);
    float y = map(rv, rMax, rMin, py0, py1);
    vertex(x, y);
  }
  endShape();

  // sense etiqueta superior del plot

  textSize(10);
  textAlign(RIGHT, TOP);
  text("t", px1, py1+16);

  pushMatrix();
  translate(gx+6, (py0+py1)/2);
  rotate(-HALF_PI);
  textAlign(CENTER, TOP);
  fill(leftCol);
  text(leftLabel, 0, 0);
  popMatrix();

  pushMatrix();
  translate(px1+51, (py0+py1)/2);
  rotate(-HALF_PI);
  textAlign(CENTER, TOP);
  fill(rightCol);
  text(rightLabel, 0, -10);
  popMatrix();

  textAlign(LEFT, BASELINE);
  drawPanelFrame(gx, gy, gwFrame, gh);
}

void drawPanelFrame(float gx, float gy, float gw, float gh) {
  noFill();
  stroke(60);
  strokeWeight(1);
  rect(gx, gy, gw, gh, 10);
}

void drawReferenceAxes(PVector origin) {
  float ox = origin.x;
  float oy = origin.y;
  float L = 22;
  strokeWeight(2);
  stroke(230, 90, 90);  // +x
  line(ox, oy, ox + L, oy);
  stroke(90, 220, 120); // +y (cap amunt en pantalla)
  line(ox, oy, ox, oy - L);
  fill(220);
  textAlign(LEFT, CENTER);
  text("x", ox + L + 4, oy);
  text("y", ox - 2, oy - L - 6);
  textAlign(LEFT, BASELINE);
  noStroke();
}

String fmtTick(float v, int decimals) {
  float av = abs(v);
  if (av < 1e-9) {
    return String.format(Locale.US, "%.1e", v);
  }
  if (av < 1e-3 || av > 1e4) {
    return String.format(Locale.US, "%.1e", v);
  }
  return nf(v, 0, decimals);
}

float plotPadL = 56;
float plotPadR = 16;
float plotPadT = 16;
float plotPadB = 34;
float plotFramePadX = 15;
float plotShiftX = -10;

void drawSeries(float[] hist,int col,float xmin,float xmax,int x,int y,int w,int h) {
  stroke(col); noFill();
  float prevY=Float.NaN;
  for (int k=0;k<histSize;k++) {
    int idx=(histIndex+k)%histSize;
    float val=hist[idx];
    float xScreen=map(k, 0, histSize-1, x+graphMargin, x+w-graphMargin);
    if (!Float.isNaN(val)) {
      float yScreen=map(val,xmin,xmax,y+h-graphMargin,y+graphMargin);
      if (!Float.isNaN(prevY)) line(xScreen-1,prevY,xScreen,yScreen);
      prevY=yScreen;
    } else prevY=Float.NaN;
  }
}

/* =================== UI BOTONS =================== */

void drawButtons() {
  textFont(uiFont);

  drawButton(btnX, btnY, btnW, btnH, "2 cossos", N==2);
  drawButton(btnX, btnY + btnH + btnGap, btnW, btnH, "3 cossos", N==3);
  drawButton(btnResetX, btnResetY, btnResetW, btnResetH, "RESET", false);
  drawButton(btnShotX, btnShotY, btnShotW, btnShotH, "Captura PNG", false);
  if (resSwitch != null) {
    resSwitch.x = btnResetX + btnResetW + 18;
    resSwitch.y = btnY + 5;
    resSwitch.lowMode = lowResMode;
    resSwitch.draw();
    fill(220);
    textAlign(LEFT, CENTER);
    text("Resolució gràfics (cal reiniciar)", resSwitch.x + resSwitch.w + 8, resSwitch.y + resSwitch.h * 0.5f);
    textAlign(LEFT, BASELINE);
  }
}

void drawButton(int x,int y,int w,int h,String label,boolean active) {
  if (active) {
    fill(230, 210, 90);
  } else {
    fill(40);
  }
  stroke(120);
  rect(x, y, w, h, 4);
  fill(active ? 20 : 220);
  textAlign(LEFT, CENTER);
  text(label, x+8, y+h*0.5);
  textAlign(LEFT, BASELINE);
}

boolean hitButton(int x,int y,int w,int h) {
  return mouseX >= x && mouseX <= x + w && mouseY >= y && mouseY <= y + h;
}

void saveScreenshotPNG() {
  saveFrame("captures/GravSim-######.png");
}

void drawTopRightLabels(float KE, float PE, float E) {
  textFont(uiFont);
  textAlign(RIGHT, TOP);
  int x = width - 12;
  int y = 12;
  int lineH = 16;
  String line1 = "N="+N+"  t="+nf(timeNow,1,2)+"  dt="+nf(dt,1,6)+"  dtBase="+nf(dtBase,1,6)
                +"  int="+(useEuler?"Euler":"Verlet")+"  dtDyn="+(adaptiveDt?"on":"off");
  String line2 = "KE="+nf(KE,1,2)+"  PE="+nf(PE,1,2)+"  E="+nf(E,1,2);
  String line3 = "[espai] pausa  [i] inicials  [n] aleatori  [v] integrador  [d] dt dinàmic";
  String line4 = "[t] rastre  [c] captura  [s] desa  [l] carrega  [e] TSV";
  String line5 = "[p] vectors v_r/v_t: " + (showPolarVectors ? "on" : "off")
               + "  [a] eixos: " + (showAxes ? "on" : "off");
  fill(255);
  text(line1, x, y);
  text(line2, x, y + lineH);
  text(line3, x, y + 2*lineH);
  text(line4, x, y + 3*lineH);
  text(line5, x, y + 4*lineH);
  if (paused) text("[PAUSAT]", x, y + 5*lineH);
  textAlign(LEFT, BASELINE);
}

void drawPolarVelocityVectors(PVector cm, PVector focus) {
  if (N < 2) return;
  int i = 1; // m1
  PVector r = PVector.sub(P[i].pos, cm);
  float rmag = max(r.mag(), 1e-6);
  PVector rhat = r.copy().div(rmag);
  PVector that = new PVector(-rhat.y, rhat.x);
  PVector vcm = centerOfMassVelocity();
  PVector vrel = PVector.sub(P[i].vel, vcm);
  float vr = PVector.dot(vrel, rhat);
  float vt = PVector.dot(vrel, that);

  float vis = 0.05f; // escala visual base
  float minLen = 18;
  float maxLen = 90;
  PVector vrVec = scaledVector(rhat, vr * vis, minLen, maxLen);
  PVector vtVec = scaledVector(that, vt * vis, minLen, maxLen);
  PVector origin = worldToScreen(P[i].pos, focus);

  drawVector(origin, vrVec, color(255, 140, 0));   // radial
  drawVector(origin, vtVec, color(80, 220, 80));  // transversal (verd)
}

PVector scaledVector(PVector dir, float signedLen, float minLen, float maxLen) {
  float sign = (signedLen < 0) ? -1 : 1;
  float len = abs(signedLen);
  if (len < 1e-4) return new PVector(0, 0);
  len = constrain(len, minLen, maxLen);
  return PVector.mult(dir, sign * len);
}

void drawVector(PVector origin, PVector v, int c) {
  stroke(c);
  strokeWeight(2);
  line(origin.x, origin.y, origin.x + v.x, origin.y + v.y);
  // fletxa simple
  float len = v.mag();
  if (len > 1e-3) {
    PVector dir = v.copy().normalize();
    PVector left = new PVector(-dir.y, dir.x);
    float ah = 6;
    PVector tip = PVector.add(origin, v);
    PVector p1 = PVector.add(tip, PVector.mult(dir, -ah));
    PVector p2 = PVector.add(p1, PVector.mult(left, ah*0.5f));
    PVector p3 = PVector.add(p1, PVector.mult(left, -ah*0.5f));
    line(tip.x, tip.y, p2.x, p2.y);
    line(tip.x, tip.y, p3.x, p3.y);
  }
  strokeWeight(1);
}

void drawSliders() {
  textFont(uiFont);
  int y = sliderY;
  for (int i=0;i<N;i++) {
    float v = massToSlider(masses[i]);
    drawSlider(sliderX, y, sliderW, sliderH, v, "m"+i+"="+nf(masses[i],1,2));
    y += sliderH + sliderGap;
  }
  for (int i=0;i<N;i++) {
    float v = velScaleToSlider(velScale[i]);
    float speed = velScale[i];
    drawSlider(sliderX, y, sliderW, sliderH, v, "v"+i+"="+nf(speed,1,2));
    y += sliderH + sliderGap;
  }
  float vd = distToSlider(distScale);
  drawSlider(sliderX, y, sliderW, sliderH, vd, "dist="+nf(distScale,1,2));
  y += sliderH + sliderGap;
  float vG = GToSlider(G);
  drawSlider(sliderX, y, sliderW, sliderH, vG, "G="+nf(G,1,1));
  y += sliderH + sliderGap;
  // subSteps eliminat
  float vDt = dtToSlider(dtBase);
  drawSlider(sliderX, y, sliderW, sliderH, vDt, "dtBase="+nf(dtBase,1,5));
}

void drawSlider(int x,int y,int w,int h,float v,String label) {
  noStroke();
  fill(30);
  rect(x, y, w, h, 4);
  fill(200);
  rect(x, y, w*v, h, 4);
  stroke(120);
  noFill();
  rect(x, y, w, h, 4);
  fill(220);
  textAlign(LEFT, CENTER);
  text(label, x+w+8, y+h*0.5);
  textAlign(LEFT, BASELINE);
}

int hitAnySlider() {
  int y = sliderY;
  for (int i=0;i<N;i++) {
    if (hitSlider(sliderX, y, sliderW, sliderH)) return i;
    y += sliderH + sliderGap;
  }
  for (int i=0;i<N;i++) {
    if (hitSlider(sliderX, y, sliderW, sliderH)) return N + i;
    y += sliderH + sliderGap;
  }
  if (hitSlider(sliderX, y, sliderW, sliderH)) return 2*N; // distancia
  y += sliderH + sliderGap;
  if (hitSlider(sliderX, y, sliderW, sliderH)) return 2*N + 1; // G
  y += sliderH + sliderGap;
  if (hitSlider(sliderX, y, sliderW, sliderH)) return 2*N + 2; // dt
  return -1;
}

boolean hitSlider(int x,int y,int w,int h) {
  return mouseX >= x && mouseX <= x + w && mouseY >= y && mouseY <= y + h;
}

void updateSliderValue(int idx, float mx) {
  float v = constrain((mx - sliderX) / (float)sliderW, 0, 1);
  if (idx >= 0 && idx < N) {
    masses[idx] = sliderToMass(v);
    if (P != null && idx < P.length && P[idx] != null) {
      P[idx].m = masses[idx];
      computeAccelerations();
    }
  } else if (idx >= N && idx < 2*N) {
    int i = idx - N;
    velScale[i] = sliderToVelScale(v);
    applyVelocityScale();
    if (P != null && i < P.length && P[i] != null) {
      P[i].vel = vel_init[i].copy();
      computeAccelerations();
    }
  } else if (idx == 2*N) {
    distScale = sliderToDist(v);
    applyDistanceScale();
    // aplica posicions en viu
    PVector C = new PVector(width*0.5, height*0.5);
    for (int i=0;i<N;i++) {
      P[i].pos = PVector.add(C, pos_init[i]);
    }
    computeAccelerations();
  } else if (idx == 2*N + 1) {
    G = sliderToG(v);
    computeAccelerations();
  } else if (idx == 2*N + 2) {
    dtBase = sliderToDt(v);
  }
}

float sliderToMass(float v) {
  return sliderToLogValue(v);
}

float massToSlider(float m) {
  return logValueToSlider(m);
}

float sliderToDist(float v) {
  return sliderToLogValue(v);
}

float distToSlider(float d) {
  return logValueToSlider(d);
}

float sliderToVelScale(float v) {
  return sliderToLogValue(v);
}

float velScaleToSlider(float s) {
  return logValueToSlider(s);
}

float sliderToG(float v) {
  return sliderToLogValue(v);
}

float GToSlider(float g) {
  return logValueToSlider(g);
}

float sliderToDt(float v) {
  return sliderToLogValue(v);
}

float dtToSlider(float d) {
  return logValueToSlider(d);
}

int sliderToPlotEvery(float v) {
  return max(plotEveryMin, min(plotEveryMax, round(map(v, 0, 1, plotEveryMin, plotEveryMax))));
}

float plotEveryToSlider(int v) {
  return constrain(map(v, plotEveryMin, plotEveryMax, 0, 1), 0, 1);
}

float sliderToLogValue(float v) {
  float lv = constrain(v, 0, 1);
  float logMin = log(sliderLogMin);
  float logMax = log(sliderLogMax);
  return exp(lerp(logMin, logMax, lv));
}

float logValueToSlider(float value) {
  float vv = constrain(max(value, sliderLogMin), sliderLogMin, sliderLogMax);
  float logMin = log(sliderLogMin);
  float logMax = log(sliderLogMax);
  return constrain((log(vv) - logMin) / max(1e-9f, (logMax - logMin)), 0, 1);
}

void applyDistanceScale() {
  for (int i=0;i<N;i++) {
    pos_init[i] = PVector.mult(base_pos_init[i], distScale);
  }
}

void applyVelocityScale() {
  for (int i=0;i<N;i++) {
    PVector dir = base_vel_init[i].copy();
    float mag = dir.mag();
    if (mag < 1e-6) {
      dir = new PVector(1, 0);
    } else {
      dir.div(mag);
    }
    vel_init[i] = PVector.mult(dir, velScale[i]);
  }
}

/* =================== GUARDAR/CARREGAR i EXPORT =================== */

// Captura l’estat actual com a noves condicions inicials (relatives al centre)
void captureCurrentAsInitials() {
  PVector C=new PVector(width*0.5,height*0.5);
  for (int i=0;i<N;i++) {
    masses[i]  = P[i].m;
    pos_init[i]= PVector.sub(P[i].pos, C);
    vel_init[i]= P[i].vel.copy();
    base_pos_init[i]= PVector.div(pos_init[i], max(distScale, 1e-6));
    base_vel_init[i]= vel_init[i].copy();
    velScale[i]= base_vel_init[i].mag();
  }
  println("Condicions inicials actualitzades a memòria.");
}

// Desa condicions inicials a JSON
void saveIC(String filename) {
  JSONObject root = new JSONObject();
  root.setInt("N", N);
  JSONArray m = new JSONArray();
  JSONArray pos = new JSONArray();
  JSONArray vel = new JSONArray();
  for (int i=0;i<N;i++) {
    m.append(masses[i]);
    JSONObject p = new JSONObject();
    p.setFloat("x", pos_init[i].x);
    p.setFloat("y", pos_init[i].y);
    pos.append(p);
    JSONObject v = new JSONObject();
    v.setFloat("x", vel_init[i].x);
    v.setFloat("y", vel_init[i].y);
    vel.append(v);
  }
  root.setJSONArray("masses", m);
  root.setJSONArray("pos_init", pos);
  root.setJSONArray("vel_init", vel);
  saveJSONObject(root, filename);
  println("Guardat a "+filename);
}

// Carrega condicions inicials des de JSON (manté N fix a l'sketch)
void loadIC(String filename) {
  try {
    JSONObject root = loadJSONObject(filename);
    int Nfile = root.getInt("N");
    if (Nfile != N) {
      println("Avís: el fitxer té N="+Nfile+" però l'sketch té N="+N+". S'usaran les primeres "+min(N,Nfile)+" partícules.");
    }
    JSONArray m = root.getJSONArray("masses");
    JSONArray pos = root.getJSONArray("pos_init");
    JSONArray vel = root.getJSONArray("vel_init");
    int count = min(N, m.size());
    for (int i=0;i<count;i++) {
      masses[i] = m.getFloat(i);
      JSONObject p = pos.getJSONObject(i);
      JSONObject v = vel.getJSONObject(i);
      pos_init[i] = new PVector(p.getFloat("x"), p.getFloat("y"));
      vel_init[i] = new PVector(v.getFloat("x"), v.getFloat("y"));
      base_pos_init[i] = pos_init[i].copy();
      base_vel_init[i] = vel_init[i].copy();
      velScale[i] = base_vel_init[i].mag();
    }
    distScale = 1.0f;
    applyDistanceScale();
    applyVelocityScale();
    println("Carregat des de "+filename);
  } catch (Exception e) {
    println("Error carregant "+filename+": "+e.getMessage());
  }
}

// Exporta l’històric x(t) en format TSV (tabulat) amb punt decimal
void exportXTSV(String filename) {
  PrintWriter out = createWriter(filename);
  // capçalera
  out.print("t");
  for (int i=0;i<N;i++) { out.print('\t'); out.print("x"+i); }
  out.println();
  // dades (buffer circular, del més antic al més recent)
  for (int k=0;k<histSize;k++) {
    int idx = (histIndex + k) % histSize;
    if (Float.isNaN(tHist[idx])) continue; // encara buit
    out.print(f6(tHist[idx]));
    for (int i=0;i<N;i++) { out.print('\t'); out.print(f6(xHist[i][idx])); }
    out.println();
  }
  out.flush();
  out.close();
  println("x(t) exportat a "+filename+" (TSV, punt decimal).");
}

/* =================== LOG DE TRAJECTÒRIA (TSV automàtic) =================== */

void openTrajectoryWriter(String label) {
  if (!autoLog) return;
  // Tanca el fitxer anterior si cal
  if (trajOut != null) {
    trajOut.flush();
    trajOut.close();
    println("Trajectòria tancada: "+trajFilename);
  }
  // Timestamp simple
  String ts = timestamp();
  trajFilename = "traj.tsv";
  trajOut = createWriter(trajFilename);

  // Capçalera: t, x0, y0, x1, y1, ...
  trajOut.print("#t");
  for (int i=0;i<N;i++) { trajOut.print('\t'); trajOut.print("x"+i); trajOut.print('\t'); trajOut.print("y"+i); }
  trajOut.println();
  trajOut.flush();
  sinceLastFlush = 0;
  println("Gravant trajectòria a "+trajFilename);
}

void logTrajectoryLine() {
  if (!autoLog) return;
  if (trajOut == null) return;
  trajOut.print(f6(timeNow));
  for (int i=0;i<N;i++) {
    trajOut.print('\t'); trajOut.print(f6(P[i].pos.x));
    trajOut.print('\t'); trajOut.print(f6(P[i].pos.y));
  }
  trajOut.println();
  sinceLastFlush++;
  if (sinceLastFlush >= flushEvery) {
    trajOut.flush();
    sinceLastFlush = 0;
  }
}

// Es crida automàticament en tancar l’sketch
void dispose() {
  if (!autoLog) return;
  if (trajOut != null) {
    trajOut.flush();
    trajOut.close();
    println("Trajectòria tancada: "+trajFilename);
  }
}

/* =================== UTILITATS =================== */

void resetTrails() {
  if (trails == null) return;
  trails.beginDraw();
  trails.background(10);
  trails.endDraw();
}

void applyViewTransform(PVector focus) {
  translate(width * 0.5f, height * 0.5f);
  scale(viewScale);
  translate(-focus.x, -focus.y);
}

PVector worldToScreen(PVector world, PVector focus) {
  return new PVector(
    width * 0.5f + (world.x - focus.x) * viewScale,
    height * 0.5f + (world.y - focus.y) * viewScale
  );
}

PVector screenToWorld(float sx, float sy, PVector focus) {
  float inv = 1.0f / max(viewScale, 1e-6f);
  return new PVector(
    focus.x + (sx - width * 0.5f) * inv,
    focus.y + (sy - height * 0.5f) * inv
  );
}

boolean hitCenterOfMass(float mx, float my) {
  if (P == null || P.length == 0) return false;
  PVector cm = centerOfMass();
  PVector focus = PVector.add(cm, viewPan);
  PVector cms = worldToScreen(cm, focus);
  float r = 6;
  return dist(mx, my, cms.x, cms.y) <= (r + 6);
}

boolean hitLargestMass(float mx, float my) {
  if (P == null || P.length == 0) return false;
  int iMax = 0;
  float mMax = -1;
  for (int i=0; i<N; i++) {
    if (P[i] == null) continue;
    if (P[i].m > mMax) {
      mMax = P[i].m;
      iMax = i;
    }
  }
  PVector cm = centerOfMass();
  PVector focus = PVector.add(cm, viewPan);
  PVector ps = worldToScreen(P[iMax].pos, focus);
  float r = 6 * pow(P[iMax].m, 1f/5f);
  return dist(mx, my, ps.x, ps.y) <= (r + 4);
}

void dragCenterOfMassTo(float mx, float my) {
  float inv = 1.0f / max(viewScale, 1e-6f);
  viewPan.set((width * 0.5f - mx) * inv, (height * 0.5f - my) * inv);
}

class TwoPosSwitch {
  float x, y, w, h;
  boolean lowMode = false;
  String leftLabel;
  String rightLabel;

  TwoPosSwitch(float x, float y, float w, float h, boolean lowMode, String leftLabel, String rightLabel) {
    this.x = x;
    this.y = y;
    this.w = w;
    this.h = h;
    this.lowMode = lowMode;
    this.leftLabel = leftLabel;
    this.rightLabel = rightLabel;
  }

  void draw() {
    float half = w * 0.5f;
    float r = h * 0.5f;

    noStroke();
    fill(0, 40);
    rect(x + 1, y + 1, w, h, r);

    fill(55);
    rect(x, y, w, h, r);

    float selX = lowMode ? x + half : x;
    fill(240, 185, 70);
    rect(selX + 1, y + 1, half - 2, h - 2, r - 1);

    stroke(120);
    strokeWeight(1);
    line(x + half, y + 2, x + half, y + h - 2);
    noFill();
    stroke(150);
    rect(x, y, w, h, r);

    noStroke();
    fill(250);
    float dotX = lowMode ? (x + half + 8) : (x + 8);
    ellipse(dotX, y + h * 0.5f, 4, 4);

    textAlign(CENTER, CENTER);
    textSize(10);
    fill(lowMode ? 210 : 15);
    text(leftLabel, x + half * 0.5f, y + h * 0.52f);
    fill(lowMode ? 15 : 210);
    text(rightLabel, x + half * 1.5f, y + h * 0.52f);
  }

  boolean hit(float mx, float my) {
    return (mx >= x && mx <= x + w && my >= y && my <= y + h);
  }

  void mousePressed(float mx, float my) {
    if (!hit(mx, my)) return;
    float half = x + w * 0.5f;
    lowMode = (mx >= half);
  }
}

int loadPixelDensityPreference() {
  try {
    String path = sketchPath(".pixel_density_pref.txt");
    String[] lines = loadStrings(path);
    if (lines != null && lines.length > 0) {
      int pd = parseInt(trim(lines[0]));
      if (pd >= 1) return pd;
    }
  } catch (Exception e) {
    // Si falla, usem la densitat per defecte de la pantalla
  }
  return displayDensity();
}

void savePixelDensityPreference(int pd) {
  String path = sketchPath(".pixel_density_pref.txt");
  saveStrings(path, new String[] { str(max(1, pd)) });
}

void clampArraysToN() {
  // garanteix longituds mínimes i omple valors per defecte si cal
  if (masses.length < N) {
    float[] mnew = new float[N];
    for (int i=0;i<N;i++) mnew[i] = (i < masses.length) ? masses[i] : 1.0f;
    masses = mnew;
  }
  if (pos_init.length < N) {
    PVector[] pnew = new PVector[N];
    for (int i=0;i<N;i++) pnew[i] = (i < pos_init.length) ? pos_init[i].copy() : new PVector();
    pos_init = pnew;
  }
  if (vel_init.length < N) {
    PVector[] vnew = new PVector[N];
    for (int i=0;i<N;i++) vnew[i] = (i < vel_init.length) ? vel_init[i].copy() : new PVector();
    vel_init = vnew;
  }
  if (base_vel_init.length < N) {
    PVector[] bvnew = new PVector[N];
    for (int i=0;i<N;i++) bvnew[i] = (i < base_vel_init.length) ? base_vel_init[i].copy() : new PVector();
    base_vel_init = bvnew;
  }
  if (velScale.length < N) {
    float[] vsnew = new float[N];
    for (int i=0;i<N;i++) vsnew[i] = (i < velScale.length) ? velScale[i] : base_vel_init[i].mag();
    velScale = vsnew;
  }
  if (base_pos_init.length < N) {
    PVector[] bnew = new PVector[N];
    for (int i=0;i<N;i++) bnew[i] = (i < base_pos_init.length) ? base_pos_init[i].copy() : new PVector();
    base_pos_init = bnew;
  }
}

PVector centerOfMass() {
  float mtot=0; PVector cm=new PVector();
  for (int i=0;i<N;i++){mtot+=P[i].m; cm.add(PVector.mult(P[i].pos,P[i].m));}
  return cm.div(mtot);
}

PVector totalMomentum() {
  PVector p=new PVector();
  for (int i=0;i<N;i++) p.add(PVector.mult(P[i].vel,P[i].m));
  return p;
}

PVector centerOfMassVelocity() {
  float mtot=0; PVector vcm=new PVector();
  for (int i=0;i<N;i++) { mtot+=P[i].m; vcm.add(PVector.mult(P[i].vel,P[i].m)); }
  return (mtot>0) ? vcm.div(mtot) : vcm;
}

PVector centerOfMassAcceleration() {
  float mtot=0; PVector acm=new PVector();
  for (int i=0;i<N;i++) { mtot+=P[i].m; acm.add(PVector.mult(P[i].acc,P[i].m)); }
  return (mtot>0) ? acm.div(mtot) : acm;
}

String dd(int v){ return nf(v,2); }
String timestamp() {
  return year()+""+dd(month())+dd(day())+"_"+dd(hour())+dd(minute())+dd(second());
}

int colorFor(int i,int alpha) {
  if (i==0) return color(255,100,100,alpha);
  if (i==1) return color(100,200,255,alpha);
  if (i==2) return color(140,255,140,alpha);
  return color(200,200,200,alpha);
}

class Particle {
  float m; PVector pos,vel,acc;
  Particle(float m,PVector pos,PVector vel){
    this.m=m; this.pos=pos.copy(); this.vel=vel.copy(); this.acc=new PVector();
  }
  void drawBody(int c){
    noStroke(); fill(c);
    float radius=6*pow(m,1f/5f);
    circle(pos.x,pos.y,radius);
  }
  void drawBodyAt(PVector p, int c){
    noStroke(); fill(c);
    float radius=6*pow(m,1f/5f);
    circle(p.x,p.y,radius);
  }
}
