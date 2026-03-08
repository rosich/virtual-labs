// ======================================================

import java.util.Locale;
// PÈNDOL DOBLE / SIMPLE — RK4 + FITXER + ENERGIA + GRÀFICS + TRAÇA TOTAL (PGraphics)
// ------------------------------------------------------
// Fitxer: pendol_doble_m2.txt amb: t   x   y   (FÍSIC)
//   - Mode DOBLE: (x,y) de m2 (massa final)
//   - Mode SIMPLE: (x,y) del bob (m1)
//
// Controls:
//  - ESPAI: pausa
//  - C: neteja estela curta
//  - X: neteja traça TOTAL (panell esquerra inferior)
//  - + / -: accelera / frena el temps físic
// ======================================================


boolean isDouble = false; // true=doble, false=simple
boolean initIsDouble = false;

// ---------- Paràmetres físics (sliders) ----------
float g  = 9.81;
float m1 = 1.0;
float m2 = 1.0;
float L1 = 1.0;   // longitud física
float L2 = 1.0;
float initG  = 9.81;
float initM1 = 1.0;
float initM2 = 1.0;
float initL1 = 1.0;
float initL2 = 1.0;

// Guardem "base" per resets
float baseM1, baseM2, baseL1, baseL2, baseG;

// ---------- Estat ----------
float initTh1 = radians(30);
float initTh2 = radians(-10);
float initW1  = 0.0;
float initW2  = 0.0;
float th1 = initTh1;
float th2 = initTh2;
float w1  = initW1;
float w2  = initW2;

float baseTh1, baseTh2, baseW1, baseW2;

// Energia objectiu (per ΔE)
float E0;
float monitorE = 0.0;
float monitorDE = 0.0;
float monitorRel = 0.0;

// ---------- Integració ----------
float dt = 1e-4; //0.01 * 1.0/180.0;
int subSteps = 1;
int physicsStepsPerFrame = 200;
float initDt = 1e-4; //0.01 * 1.0/180.0;
int initSubSteps = 1;
int initPhysicsStepsPerFrame = 200;

float time = 0.0;
int stepCounter = 0;
int energyEvery = 200;

// ---------- Dibuix ----------
PVector origin;

// escala de dibuix (px per unitat física)
float drawScale;

// Estela curta (buffer circular) EN PÍXELS
PVector[] trail;
int trailIndex = 0;
int trailLength = 300;

boolean paused = false;
boolean showSpectrum = false;
boolean spectrumLogY = true;
boolean spectrumUseDFT = true;
float spectrumFMin = 0.0;
int spectrumFreqPoints = 5000;
boolean spectrumLogF = true;
int spectrumXTicks = 8;
int spectrumEveryPoints = 1000;
long xySamplesTotal = 0;
long lastSpectrumSamples = 0;
float lastFNyq = 0.0;
//init variables
boolean initShowSpectrum = false;
boolean initSpectrumLogY = true;
boolean initSpectrumUseDFT = true;
float initSpectrumFMin = 0.0;
int initSpectrumFreqPoints = 5000;
boolean initSpectrumLogF = true;
int initSpectrumXTicks = 8;
int initSpectrumEveryPoints = 1000;

// ---------- Gravació (manual) ----------
PrintWriter trajWriter;
PrintWriter xyWriter;
PrintWriter angWriter;
boolean recTraj = false;
boolean recXY = false;
boolean recAng = false;

// ---------- Layout (columna esquerra) ----------
float margin = 18;
float gap = 16;
float panelW = 500;
float panelH = 185;
float leftMenuGap = 8;
float leftButtonGap = 6;
float leftBlockGap = 0;
float leftPanelGap = 32;
float leftSpectrumGap = 10;

// Energia panel
float eneGX, eneGY, eneGW, eneGH;
// Trajectòria panel
float trajGX, trajGY, trajGW, trajGH;
// X,Y vs t panel
float xyGX, xyGY, xyGW, xyGH;
// θ, ω vs t panel (dreta)
float angGX, angGY, angGW, angGH;
// Sliders panel (dreta)
float sliderGX, sliderGY, sliderGW, sliderGH;

// Marc gruixut
float frameW = 1;

// Zona de gràfica interna (padding per eixos)
float plotPadL = 56;
float plotPadR = 16;
float plotPadT = 16;
float plotPadB = 34;
float plotFramePadX = 15;
float plotShiftX = -10;

// ---------- UI ----------
ModeToggle modeToggle;
Button btnAngles;
Button btnParams;
Button btnResetAll;
Button btnSpectrum;
Button btnSpecScale;
Button btnSpecAlgo;
Button btnSpecRecalc;
Button btnTrajCap;
Button btnXYCap;
Button btnAngCap;
Button btnTrajAuto;
Button btnScreenshot;
Knob knobSpeed;
Knob knobScale;
boolean manualScale = true;
Slider sM1, sM2, sL1, sL2, sG;
Slider sTh1, sTh2;

// ---------- Mostreig per gràfics ----------
int graphEvery = 100;

// ---------- Gràfic x,y vs t ----------
int xyHistoryN = 1000;
float[] tXYBuf = new float[xyHistoryN];
float[] xBuf = new float[xyHistoryN];
float[] yBuf = new float[xyHistoryN];
int xyIndex = 0;
boolean xyFilled = false;
FloatList tAll = new FloatList();
FloatList xAll = new FloatList();
FloatList yAll = new FloatList();

// ---------- Gràfic θ, ω vs t ----------
int angHistoryN = 1000;
float[] tAngBuf = new float[angHistoryN];
float[] thBuf = new float[angHistoryN];
float[] wBuf = new float[angHistoryN];
int angIndex = 0;
boolean angFilled = false;

// ---------- Espectre ----------
int spectrumHistoryN = 200000;  //nombre de punts de la història de x(t) i y(t) que s'utilitzen per calcular FFT/DFT
float[] fftX = new float[spectrumHistoryN];
float[] fftY = new float[spectrumHistoryN];
float[] fftT = new float[spectrumHistoryN];
float[] specX = new float[spectrumHistoryN/2];
float[] specY = new float[spectrumHistoryN/2];
float[] specF = new float[spectrumHistoryN/2];
float[] fftImX = new float[spectrumHistoryN];
float[] fftImY = new float[spectrumHistoryN];
int specN = 0;
boolean spectrumFrozen = false;

// ---------- Trajectòria TOTAL (PGraphics) ----------
PGraphics trajLayer;
boolean trajHasPrev = false;
float trajPrevX, trajPrevY;
int trajDrawEvery = 100;
int trajHistoryN = 20000;
float[] trajXBuf = new float[trajHistoryN];
float[] trajYBuf = new float[trajHistoryN];
int trajIndex = 0;
boolean trajFilled = false;
float trajMinX, trajMaxX, trajMinY, trajMaxY;
boolean trajBoundsInit = false;
float trajViewMinX, trajViewMaxX, trajViewMinY, trajViewMaxY;
boolean trajViewActive = false;

// Traç molt fi
float trajGlowW = 0.8;
float trajLineW = 0.25;

// ---------- Menú mode (segmented control) ----------
class ModeToggle {
  float x, y, w, h;
  ModeToggle(float x, float y, float w, float h) { this.x=x; this.y=y; this.w=w; this.h=h; }
  void draw() {
    stroke(240);
    strokeWeight(0.9);
    fill(25);
    rect(x, y, w, h, 10);

    float half = w/2;

    noStroke();
    fill(!isDouble ? 70 : 40);
    rect(x, y, half, h, 10);
    fill(isDouble ? 70 : 40);
    rect(x+half, y, half, h, 10);

    fill(240);
    textAlign(CENTER, CENTER);
    textSize(12);
    text("SIMPLE", x + half*0.5, y + h*0.5);
    text("DOBLE", x + half*1.5, y + h*0.5);
    textAlign(LEFT, BASELINE);

    noFill();
    stroke(240);
    strokeWeight(0.9);
    rect(x, y, w, h, 10);
  }

  void mousePressed() {
    if (mouseX < x || mouseX > x+w || mouseY < y || mouseY > y+h) return;
    boolean clickedDouble = mouseX >= x + w/2;
    if (clickedDouble != isDouble) switchMode(clickedDouble);
  }
}

// ---------- Botons ----------
class Button {
  float x, y, w, h;
  String label;
  boolean textOnly = false;
  boolean light = false;
  Button(float x, float y, float w, float h, String label) {
    this.x=x; this.y=y; this.w=w; this.h=h; this.label=label;
  }
  boolean hover() { return mouseX>=x && mouseX<=x+w && mouseY>=y && mouseY<=y+h; }
  boolean hit(float mx, float my) { return mx>=x && mx<=x+w && my>=y && my<=y+h; }
  void draw() {
    if (!textOnly) {
      stroke(240); strokeWeight(1);
      if (light) fill(hover() ? 200 : 175);
      else fill(hover() ? 60 : 35);
      rect(x, y, w, h, 10);
      fill(light ? 20 : 240);
    } else {
      noStroke();
      fill(hover() ? 255 : 220);
    }
    textAlign(CENTER, CENTER);
    textSize(12);
    text(label, x+w/2, y+h/2);
    textAlign(LEFT, BASELINE);
  }
}

// ---------- Sliders ----------
class Slider {
  float x, y, w, h;
  float vmin, vmax;
  float value;
  String label;
  boolean dragging = false;
  boolean enabled = true;

  Slider(float x, float y, float w, float h, float vmin, float vmax, float value, String label) {
    this.x=x; this.y=y; this.w=w; this.h=h;
    this.vmin=vmin; this.vmax=vmax;
    this.value=value;
    this.label=label;
  }

  void setEnabled(boolean e) { enabled = e; }

  void draw() {
    stroke(240);
    strokeWeight(1);
    fill(enabled ? 25 : 18);
    rect(x, y, w, h, 10);

    float tx0 = x + 10;
    float tx1 = x + w - 10;
    float ty  = y + h*0.62;

    stroke(enabled ? 140 : 80);
    strokeWeight(2);
    line(tx0, ty, tx1, ty);

    float t = constrain((value - vmin) / (vmax - vmin), 0, 1);
    float kx = lerp(tx0, tx1, t);
    float ky = ty;

    noStroke();
    fill(enabled ? 240 : 120);
    ellipse(kx, ky, 12, 12);

    fill(240);
    textSize(11);
    textAlign(LEFT, TOP);
    String vs = (abs(value) >= 100) ? nf(value, 0, 0)
             : (abs(value) >= 10)  ? nf(value, 0, 2)
             : nf(value, 0, 3);
    text(label + " = " + vs, x + 10, y + 4);
    textAlign(LEFT, BASELINE);
  }

  boolean hit(float mx, float my) {
    return enabled && mx>=x && mx<=x+w && my>=y && my<=y+h;
  }

  void mousePressed() {
    if (!hit(mouseX, mouseY)) return;
    dragging = true;
    updateFromMouse();
  }

  void mouseDragged() {
    if (!dragging) return;
    updateFromMouse();
  }

  void mouseReleased() { dragging = false; }

  void updateFromMouse() {
    float tx0 = x + 10;
    float tx1 = x + w - 10;
    float t = constrain((mouseX - tx0) / (tx1 - tx0), 0, 1);
    value = lerp(vmin, vmax, t);
  }
}

// ---------- Knob ----------
class Knob {
  float x, y, r;
  float vmin, vmax;
  float value;
  String label;
  boolean dragging = false;
  boolean showX = true;
  boolean sci = false;
  boolean showLabel = true;

  Knob(float x, float y, float r, float vmin, float vmax, float value, String label) {
    this.x=x; this.y=y; this.r=r;
    this.vmin=vmin; this.vmax=vmax;
    this.value=value;
    this.label=label;
  }

  void setValue(float v) { value = constrain(v, vmin, vmax); }

  void updateFromMouse() {
    float ang = atan2(mouseY - y, mouseX - x);
    float minA = -PI * 0.75;
    float maxA = PI * 0.75;
    ang = constrain(ang, minA, maxA);
    value = map(ang, minA, maxA, vmin, vmax);
  }

  void mousePressed() {
    if (dist(mouseX, mouseY, x, y) <= r) {
      dragging = true;
      updateFromMouse();
    }
  }

  void mouseDragged() {
    if (dragging) updateFromMouse();
  }

  void mouseReleased() { dragging = false; }

  void draw() {
    float minA = -PI * 0.75;
    float maxA = PI * 0.75;
    float ang = map(value, vmin, vmax, minA, maxA);

    noFill();
    stroke(80);
    strokeWeight(3);
    arc(x, y, r*2, r*2, minA, maxA);

    stroke(220);
    strokeWeight(2);
    float px = x + cos(ang) * r*0.8;
    float py = y + sin(ang) * r*0.8;
    line(x, y, px, py);
    fill(220);
    noStroke();
    ellipse(x, y, 5, 5);

    fill(220);
    textSize(10);
    textAlign(CENTER, TOP);
    String vtxt = sci ? fmtSci(value) : nf(value, 0, 0);
    if (showLabel) text(label + " " + vtxt + (showX ? "x" : ""), x, y + r + 4);
    textAlign(LEFT, BASELINE);
  }
}

String fmtSci(float v) {
  return String.format(Locale.US, "%.1e", v);
}

// ======================================================
void setup() {
  size(1500, 830);
  frameRate(60);

  trail = new PVector[trailLength];

  computeLayout();      // col·loca panells i origen
  computeDrawScale();   // calcula drawScale per encaixar
  drawScale = isDouble ? 200 : 300;

  // Bases
  baseM1 = m1; baseM2 = m2;
  baseL1 = L1; baseL2 = L2;
  baseG  = g;

  baseTh1 = th1; baseTh2 = th2;
  baseW1  = w1;  baseW2  = w2;

  E0 = energyTotal();
  updateEnergyMonitor();

  // UI esquerra
  float bx = margin;
  float by = margin;

  modeToggle = new ModeToggle(bx, by, panelW, 30);

  float bh = 30;
  float bgap = leftButtonGap;
  float bwReset = panelW * 0.5;
  float by0 = by + 30 + leftMenuGap;
  btnAngles = new Button(bx, by0, bwReset, bh, "Reset ~E0 (angles)");
  btnParams = new Button(bx, by0 + bh + bgap, bwReset, bh, "Reset ~E0 (paràmetres)");
  btnResetAll = new Button(bx, by0 + 2*(bh + bgap), bwReset, bh, "RESET");

  // Capa persistent trajectòria (mida exacta del panell)
  trajLayer = createGraphics(int(trajGW), int(trajGH));
  clearTrajectoryLayer();

  layoutSliders();
  layoutSpectrumButton();
  layoutGraphButtons();
}

// ======================================================
void computeLayout() {
  // sota menú + 3 botons
  float menuH = 30;
  float menuGap = leftMenuGap;
  float btnH = 30;
  float btnGap = leftButtonGap;
  float buttonsBlockH = btnH * 3 + btnGap * 2;
  float topY = margin + menuH + menuGap + buttonsBlockH + leftBlockGap;
  float spectrumAreaH = 28 + leftSpectrumGap;
  float plotGap = leftPanelGap;
  float plotExtraW = 15;
  panelH = floor((height - margin - topY - 2*plotGap - spectrumAreaH) / 3.0 - 20);

  // panells a l'esquerra
  eneGX = margin;  eneGW = panelW;  eneGH = panelH;
  trajGX = margin; trajGW = panelW + plotExtraW; trajGH = panelH;
  xyGX = margin;   xyGW  = panelW + plotExtraW;  xyGH  = panelH;
  angGX = margin;  angGW = panelW + plotExtraW;  angGH = panelH;

  eneGY  = topY + leftBlockGap;
  trajGY = topY;
  angGY  = trajGY + trajGH + plotGap;
  xyGY   = angGY + angGH + plotGap;
  float plotBlockBottom = xyGY + xyGH + spectrumAreaH;
  float plotShift = (height - 25) - plotBlockBottom;
  trajGY += plotShift;
  angGY  += plotShift;
  xyGY   += plotShift;

  // zona dreta disponible
  float rightX0 = panelW + plotExtraW + margin*2;
  float rightX1 = width - margin;
  float rightY0 = margin + 10;
  float rightY1 = height - margin;

  float rightW = rightX1 - rightX0;
  float rightH = rightY1 - rightY0;

  // sliders (dreta, alineats amb x(t), y(t))
  sliderGX = angGX + angGW + gap;
  sliderGY = xyGY + 20;
  sliderGH = panelH;
  sliderGW = max(180, rightX1 - sliderGX);

  origin = new PVector(rightX0 + rightW*0.52, rightY0 + rightH*0.28);
  if (isDouble) origin.y -= 30;
  else origin.y -= 40;
}

// Escala de dibuix perquè càpiga a la zona dreta sense tocar la física
void computeDrawScale() {
  if (manualScale) return;
  float rightX0 = panelW + margin*2;
  float rightX1 = width - margin;
  float rightY0 = margin + 10;
  float rightY1 = height - margin;

  float rightW = rightX1 - rightX0;
  float rightH = rightY1 - rightY0;

  float maxRpx = min(rightW*0.42, rightH*0.42);

  float Rphys = isDouble ? (L1 + L2) : L1;
  if (Rphys < 1e-6) Rphys = 1e-6;

  drawScale = 0.95 * (maxRpx / Rphys);
}

void updateSliderEnables() {
  sM2.setEnabled(isDouble);
  sL2.setEnabled(isDouble);
  sTh2.setEnabled(isDouble);
}

void layoutSliders() {
  float sx = sliderGX + 20;
  float sw = (sliderGW - 60) / 2.0;
  float sh = 26;
  float sy = sliderGY;
  float dy = sh * 1.5;
  float colGap = 20;
  float sx2 = sx + sw + colGap;

  sM1 = new Slider(sx, sy + 0*dy, sw, sh, 0.1, 10.0, m1, "m1(Kg)");
  sM2 = new Slider(sx, sy + 1*dy, sw, sh, 0.1, 10.0, m2, "m2(Kg)");
  sL1 = new Slider(sx, sy + 2*dy, sw, sh, 0.2, 5.0,  L1, "L1(m)");
  sL2 = new Slider(sx, sy + 3*dy, sw, sh, 0.2, 5.0,  L2, "L2(m)");
  sTh1 = new Slider(sx2, sy + 0*dy, sw, sh, -180.0, 180.0, degrees(initTh1), "θ1(deg)");
  sTh2 = new Slider(sx2, sy + 1*dy, sw, sh, -180.0, 180.0, degrees(initTh2), "θ2(deg)");
  sG  = new Slider(sx2, sy + 2*dy, sw, sh, 0.1, 30.0, g,  "g (m/s2)");

  updateSliderEnables();
}

void updateSpectrumButtonLabel() {
  btnSpectrum.label = showSpectrum ? "Mostra x(t), y(t)" : "Mostra espectre (DFT/FFT)";
  btnSpecScale.label = spectrumLogY ? "log" : "lin";
  btnSpecAlgo.label = spectrumUseDFT ? "DFT" : "FFT";
}

void layoutSpectrumButton() {
  float bx = margin;
  float by = xyGY + xyGH + leftSpectrumGap;
  float bw = panelW * 0.5;
  float bh = 28;

  if (btnSpectrum == null) btnSpectrum = new Button(bx, by, bw, bh, "");
  else { btnSpectrum.x = bx; btnSpectrum.y = by; btnSpectrum.w = bw; btnSpectrum.h = bh; }

  float bwR = 80;
  float bxR = bx + bw + 10;
  if (btnSpecRecalc == null) btnSpecRecalc = new Button(bxR, by, bwR, bh, "Refrescar");
  else { btnSpecRecalc.x = bxR; btnSpecRecalc.y = by; btnSpecRecalc.w = bwR; btnSpecRecalc.h = bh; }

  textSize(12);
  float padW = 12;
  String scaleLabel = spectrumLogY ? "log" : "Y lineal";
  float bw2 = textWidth(scaleLabel) + padW;
  float bh2 = 20;
  float bx2 = xyGX + xyGW - bw2 - 50;
  float by2In = xyGY + 10;
  if (btnSpecScale == null) btnSpecScale = new Button(bx2 - 20, by2In, bw2, bh2, "");
  else { btnSpecScale.x = bx2 - 20; btnSpecScale.y = by2In; btnSpecScale.w = bw2; btnSpecScale.h = bh2; }
  btnSpecScale.label = scaleLabel;
  btnSpecScale.textOnly = true;

  String algoLabel = spectrumUseDFT ? "DFT" : "FFT";
  float bw3 = textWidth(algoLabel) + padW;
  float bh3 = 20;
  float gapSpec = 8;
  float bx3 = (bx2 - 20) - bw3 - gapSpec;
  float by3 = by2In;
  if (btnSpecAlgo == null) btnSpecAlgo = new Button(bx3, by3, bw3, bh3, "");
  else { btnSpecAlgo.x = bx3; btnSpecAlgo.y = by3; btnSpecAlgo.w = bw3; btnSpecAlgo.h = bh3; }
  btnSpecAlgo.label = algoLabel;
  btnSpecAlgo.textOnly = true;

  updateSpectrumButtonLabel();
}

void layoutGraphButtons() {
  float bw = 110;
  float bh = 16;

  float tx = trajGX + trajGW + 15 - bw;
  float ty = trajGY - (bh + 6);
  if (btnTrajCap == null) btnTrajCap = new Button(tx, ty, bw, bh, "Inici captura dades");
  else { btnTrajCap.x = tx; btnTrajCap.y = ty; btnTrajCap.w = bw; btnTrajCap.h = bh; }
  btnTrajCap.light = true;

  float xx = xyGX + xyGW + 15 - bw;
  float xy = xyGY - (bh + 6);
  if (btnXYCap == null) btnXYCap = new Button(xx, xy, bw, bh, "Inici captura dades");
  else { btnXYCap.x = xx; btnXYCap.y = xy; btnXYCap.w = bw; btnXYCap.h = bh; }
  btnXYCap.light = true;

  float ax = angGX + angGW + 15 - bw;
  float ay = angGY - (bh + 6);
  if (btnAngCap == null) btnAngCap = new Button(ax, ay, bw, bh, "Inici captura dades");
  else { btnAngCap.x = ax; btnAngCap.y = ay; btnAngCap.w = bw; btnAngCap.h = bh; }
  btnAngCap.light = true;

  float aw = 56;
  float ah = 18;
  float axIn = trajGX + trajGW - aw - 8;
  float ayIn = trajGY + 8;
  if (btnTrajAuto == null) btnTrajAuto = new Button(axIn, ayIn, aw, ah, "Autoscale");
  else { btnTrajAuto.x = axIn; btnTrajAuto.y = ayIn; btnTrajAuto.w = aw; btnTrajAuto.h = ah; }
}

// ======================================================
// POSICIONS FÍSIQUES (unitats de longitud) — usen L1/L2
// Origen físic al pivot: (0,0). Convenció: y positiva cap avall.
// ======================================================
PVector mass1PosPhys() {
  float x1 = L1 * sin(th1);
  float y1 = L1 * cos(th1);
  return new PVector(x1, y1);
}

PVector bobPosPhys() {
  PVector p1 = mass1PosPhys();
  if (!isDouble) return p1;

  float x2 = p1.x + L2 * sin(th2);
  float y2 = p1.y + L2 * cos(th2);
  return new PVector(x2, y2);
}

// Físic -> pantalla (píxels)
PVector physToScreen(PVector pPhys) {
  return new PVector(
    origin.x + pPhys.x * drawScale,
    origin.y + pPhys.y * drawScale
  );
}

// ======================================================
void draw() {
  background(18);

  // sincronitza paràmetres des de sliders
  boolean changed = applyParamsFromSliders();
  if (changed) {
    computeDrawScale();
  }

  // ----- Física -----
  if (!paused) {
    for (int k = 0; k < physicsStepsPerFrame; k++) {
      float h = dt / subSteps;
      for (int i = 0; i < subSteps; i++) {

        stepRK4(h);
        time += h;
        stepCounter++;

        if (stepCounter % energyEvery == 0) {
          updateEnergyMonitor();
        }

        // Energia
        if (stepCounter % graphEvery == 0) {
          PVector p = bobPosPhys();
          pushXYPoint(time, p.x, p.y);
          pushAnglePoint(time, th1, w1);
          if (recXY && xyWriter != null) xyWriter.println(time + "\t" + p.x + "\t" + p.y);
          if (recAng && angWriter != null) angWriter.println(time + "\t" + th1 + "\t" + w1);
        }

        // Trajectòria TOTAL persistent — ARA usa físic
        if (stepCounter % trajDrawEvery == 0) {
          PVector p = bobPosPhys();
          addToTrajectoryLayer(p.x, p.y);
          if (recTraj && trajWriter != null) trajWriter.println(time + "\t" + p.x + "\t" + p.y);
        }

      }
    }
  }

  // ----- Dibuix pèndol i estela curta (dreta) -----
  PVector p1Phys = mass1PosPhys();
  PVector p2Phys = bobPosPhys();

  PVector p1 = physToScreen(p1Phys);
  PVector p2 = physToScreen(p2Phys);

  // estela curta (guardem en píxels)
  trail[trailIndex] = new PVector(p2.x, p2.y);
  trailIndex = (trailIndex + 1) % trailLength;

  // glow estela curta
  noFill();
  stroke(255, 255, 0, 45);
  strokeWeight(0.18);
  beginShape();
  for (int j = 0; j < trailLength; j++) {
    int idx = (trailIndex + j) % trailLength;
    if (trail[idx] != null) vertex(trail[idx].x, trail[idx].y);
  }
  endShape();

  // traç principal estela curta
  stroke(255, 255, 0);
  strokeWeight(0.6);
  beginShape();
  for (int j = 0; j < trailLength; j++) {
    int idx = (trailIndex + j) % trailLength;
    if (trail[idx] != null) vertex(trail[idx].x, trail[idx].y);
  }
  endShape();

  // barres
  stroke(240);
  strokeWeight(2);
  line(origin.x, origin.y, p1.x, p1.y);
  if (isDouble) line(p1.x, p1.y, p2.x, p2.y);

  // masses
  noStroke();
  fill(220);
  ellipse(origin.x, origin.y, 6, 6);
  pushStyle();
  stroke(255, 0, 255);
  strokeWeight(2);
  line(origin.x - 6, origin.y, origin.x + 6, origin.y);
  line(origin.x, origin.y - 6, origin.x, origin.y + 6);
  fill(255, 0, 255);
  textSize(12);
  textAlign(LEFT, CENTER);
  text("(0,0)", origin.x + 8, origin.y);
  popStyle();

  noStroke();
  fill(120, 200, 255);
  ellipse(p1.x, p1.y, 22, 22);

  if (isDouble) {
    noStroke();
    fill(255, 160, 120);
    ellipse(p2.x, p2.y, 22, 22);
  }

  // HUD dreta
  fill(230);
  textSize(12);
  float hudX = panelW + margin*2 + 20;
  float knobR = 18;
  float knobGap = 18;
  float knobY = margin + 60;
  float velX = width - margin - knobR;
  float escX = velX - (knobR * 2 + knobGap);
  float shotW = 96;
  float shotH = 24;
  float shotGap = 14;
  float shotX = escX - knobR - shotGap - shotW;
  float shotY = (knobY - knobR - 37) - shotH * 0.5 + 6;
  if (btnScreenshot == null) btnScreenshot = new Button(shotX, shotY, shotW, shotH, "Captura PNG");
  else { btnScreenshot.x = shotX; btnScreenshot.y = shotY; btnScreenshot.w = shotW; btnScreenshot.h = shotH; }
  if (knobScale == null) knobScale = new Knob(escX, knobY, knobR, 50, 400, drawScale, "");
  else { knobScale.x = escX; knobScale.y = knobY; }
  knobScale.showLabel = false;
  if (!knobScale.dragging) knobScale.setValue(drawScale);
  else drawScale = knobScale.value;
  btnScreenshot.draw();
  knobScale.draw();
  if (knobSpeed == null) knobSpeed = new Knob(velX, knobY, knobR, 10, 1500, physicsStepsPerFrame, "");
  else { knobSpeed.x = velX; knobSpeed.y = knobY; }
  knobSpeed.showLabel = false;
  if (!knobSpeed.dragging) knobSpeed.setValue(physicsStepsPerFrame);
  else physicsStepsPerFrame = max(1, round(knobSpeed.value));
  knobSpeed.draw();
  textAlign(CENTER, TOP);
  textSize(12);
  float labelY = knobY - knobR - 37;
  float valueY = labelY + 14;
  text("Escala", escX, labelY);
  text("Velocitat", velX, labelY);
  textSize(11);
  text(nf(round(drawScale), 0, 0), escX, valueY);
  text(nf(physicsStepsPerFrame, 0, 0), velX, valueY);
  textAlign(LEFT, BASELINE);
  text("MODE: " + (isDouble ? "DOBLE" : "SIMPLE") +
       "  | ESPAI pausa | C estela | X traça TOTAL | +/- velocitat (" + physicsStepsPerFrame + "x)",
       hudX, 22);
  float hudXMetrics = hudX;
  text("t=" + nf(time, 0, 2) + "   steps=" + stepCounter, hudXMetrics, 42);
  text("θ1(rad)=" + nf(th1, 0, 3) + "  ω1(rad/s)=" + nf(w1, 0, 3), hudXMetrics, 62);
  if (isDouble) {
    text("θ2(rad)=" + nf(th2, 0, 3) + "  ω2(rad/s)=" + nf(w2, 0, 3), hudXMetrics, 80);
  }

  // ----- Columna esquerra -----
  modeToggle.draw();
  btnAngles.draw();
  btnParams.draw();
  btnResetAll.draw();

  drawEnergyDial(eneGX, eneGY, eneGW, eneGH, monitorRel);
  drawTrajectoryPanel();
  btnTrajAuto.draw();
  drawXYGraph(xyGX, xyGY, xyGW, xyGH);
  drawAngleGraph(angGX, angGY, angGW, angGH);
  btnTrajCap.label = recTraj ? "Final captura dades" : "Inici captura dades";
  btnXYCap.label = showSpectrum
    ? "Captura espectre"
    : (recXY ? "Final captura dades" : "Inici captura dades");
  btnAngCap.label = recAng ? "Final captura dades" : "Inici captura dades";
  btnTrajCap.draw();
  btnXYCap.draw();
  btnAngCap.draw();
  btnSpectrum.draw();
  if (showSpectrum) {
    btnSpecRecalc.draw();
    btnSpecScale.draw();
    btnSpecAlgo.draw();
  }

  // Sliders
  fill(230);
  textSize(12);
  text("Paràmetres inicials", sliderGX + 20, sliderGY - 18);
  sM1.draw();
  sM2.draw();
  sL1.draw();
  sL2.draw();
  sG.draw();
  sTh1.draw();
  sTh2.draw();
}

// ======================================================
// Sliders -> variables. Retorna true si hi ha canvi
// ======================================================
boolean applyParamsFromSliders() {
  boolean changed = false;

  float nm1 = sM1.value;
  float nm2 = sM2.value;
  float nL1 = sL1.value;
  float nL2 = sL2.value;
  float ng  = sG.value;
  float nth1 = radians(sTh1.value);
  float nth2 = radians(sTh2.value);

  if (abs(nm1 - m1) > 1e-9) { m1 = nm1; changed = true; }
  if (isDouble && abs(nm2 - m2) > 1e-9) { m2 = nm2; changed = true; }
  if (abs(nL1 - L1) > 1e-9) { L1 = max(1e-6, nL1); changed = true; }
  if (isDouble && abs(nL2 - L2) > 1e-9) { L2 = max(1e-6, nL2); changed = true; }
  if (abs(ng - g) > 1e-9) { g = max(1e-6, ng); changed = true; }
  if (abs(nth1 - initTh1) > 1e-9) { initTh1 = nth1; changed = true; }
  if (abs(nth2 - initTh2) > 1e-9) { initTh2 = nth2; changed = true; }

  return changed;
}

// ======================================================
// ENERGIA (mode-dependent) — usa L1/L2 físiques
// ======================================================
float energyTotal() {
  if (!isDouble) {
    float T = 0.5 * m1 * (L1*L1) * (w1*w1);
    float V = -m1 * g * L1 * cos(th1);
    return T + V;
  } else {
    float delta = th1 - th2;

    float T =
      0.5 * m1 * (L1*L1) * (w1*w1)
      + 0.5 * m2 * ( (L1*L1)*(w1*w1) + (L2*L2)*(w2*w2) + 2*L1*L2*w1*w2*cos(delta) );

    float V =
      -(m1 + m2) * g * L1 * cos(th1)
      - m2 * g * L2 * cos(th2);

    return T + V;
  }
}

void updateEnergyMonitor() {
  monitorE = energyTotal();
  monitorDE = monitorE - E0;
  monitorRel = (abs(E0) > 1e-9) ? (monitorDE / E0) : 0.0;
}

void pushXYPoint(float t, float x, float y) {
  tXYBuf[xyIndex] = t;
  xBuf[xyIndex] = x;
  yBuf[xyIndex] = y;
  xyIndex++;
  xySamplesTotal++;
  if (xyIndex >= xyHistoryN) { xyIndex = 0; xyFilled = true; }
  tAll.append(t);
  xAll.append(x);
  yAll.append(y);
}

void pushAnglePoint(float t, float th, float w) {
  tAngBuf[angIndex] = t;
  thBuf[angIndex] = th;
  wBuf[angIndex] = w;
  angIndex++;
  if (angIndex >= angHistoryN) { angIndex = 0; angFilled = true; }
}

// ======================================================
// RELLOTGE ΔE/E0 (agulla analògica)
// ======================================================
void drawEnergyDial(float gx, float gy, float gw, float gh, float rel) {
  float r = min(gw, gh) * 0.17;
  float cx = width - margin - r;
  float cy = margin + r;

  textAlign(LEFT, BASELINE);
}

// ======================================================
// GRÀFIC x(t), y(t)
// ======================================================
void drawXYGraph(float gx, float gy, float gw, float gh) {
  if (showSpectrum) {
    drawXYSpectrum(gx, gy, gw, gh);
    return;
  }
  float gwFrame = gw + 15;

  noStroke();
  fill(25);
  rect(gx, gy, gwFrame, gh, 10);

  int n = xyFilled ? xyHistoryN : xyIndex;
  if (n < 2) {
    fill(230);
    textSize(12);
    text("x(t), y(t) (esperant dades...)", gx+10, gy+10);
    drawPanelFrame(gx, gy, gwFrame, gh);
    return;
  }

  float px0 = gx + plotPadL + plotFramePadX + plotShiftX;
  float px1 = gx + gwFrame - plotPadR - 24 - plotFramePadX + plotShiftX;
  float py0 = gy + plotPadT;
  float py1 = gy + gh - plotPadB;

  float tMin = Float.POSITIVE_INFINITY, tMax = Float.NEGATIVE_INFINITY;
  float xMin = Float.POSITIVE_INFINITY, xMax = Float.NEGATIVE_INFINITY;
  float yMin = Float.POSITIVE_INFINITY, yMax = Float.NEGATIVE_INFINITY;
  for (int i = 0; i < n; i++) {
    int idx = xyFilled ? (xyIndex + i) % xyHistoryN : i;
    float tt = tXYBuf[idx];
    float xv = xBuf[idx];
    float yv = yBuf[idx];
    tMin = min(tMin, tt);
    tMax = max(tMax, tt);
    xMin = min(xMin, xv);
    xMax = max(xMax, xv);
    yMin = min(yMin, yv);
    yMax = max(yMax, yv);
  }
  if (tMax - tMin < 1e-9) tMax = tMin + 1;
  if (xMax - xMin < 1e-9) { xMax = xMin + 1; xMin -= 1; }
  if (yMax - yMin < 1e-9) { yMax = yMin + 1; yMin -= 1; }

  strokeWeight(1);
  stroke(120);
  line(px0, py0, px0, py1);
  line(px1, py0, px1, py1);
  line(px0, py1, px1, py1);

  int xticks = 5;
  fill(230);
  textSize(10);
  for (int k = 0; k <= xticks; k++) {
    float tt = lerp(tMin, tMax, k/(float)xticks);
    float x = map(tt, tMin, tMax, px0, px1);
    stroke(120);
    line(x, py1, x, py1+4);
    noStroke();
    textAlign(CENTER, TOP);
    text(nf(tt, 0, 1), x, py1+6);
  }

  int yticks = 4;
  for (int k = 0; k <= yticks; k++) {
    float val = lerp(xMin, xMax, k/(float)yticks);
    float y = map(val, xMax, xMin, py0, py1);
    stroke(120);
    line(px0-4, y, px0, y);
    noStroke();
    textAlign(RIGHT, CENTER);
    text(nf(val, 0, 2), px0-6, y);
  }
  for (int k = 0; k <= yticks; k++) {
    float val = lerp(yMin, yMax, k/(float)yticks);
    float y = map(val, yMax, yMin, py0, py1);
    stroke(120);
    line(px1, y, px1+4, y);
    noStroke();
    textAlign(LEFT, CENTER);
    text(nf(val, 0, 2), px1+6, y);
  }
  textAlign(LEFT, BASELINE);

  stroke(80, 200, 255);
  strokeWeight(0.9);
  noFill();
  beginShape();
  for (int i = 0; i < n; i++) {
    int idx = xyFilled ? (xyIndex + i) % xyHistoryN : i;
    float x = map(tXYBuf[idx], tMin, tMax, px0, px1);
    float y = map(xBuf[idx], xMax, xMin, py0, py1);
    vertex(x, y);
  }
  endShape();

  stroke(255, 170, 80);
  strokeWeight(0.9);
  beginShape();
  for (int i = 0; i < n; i++) {
    int idx = xyFilled ? (xyIndex + i) % xyHistoryN : i;
    float x = map(tXYBuf[idx], tMin, tMax, px0, px1);
    float y = map(yBuf[idx], yMax, yMin, py0, py1);
    vertex(x, y);
  }
  endShape();

  fill(230);
  textSize(12);
  textAlign(LEFT, BASELINE);
  text("x(t), y(t)", gx+10, gy-10);

  textSize(10);
  textAlign(RIGHT, TOP);
  text("t", px1, py1+16);

  pushMatrix();
  translate(gx+6, (py0+py1)/2);
  rotate(-HALF_PI);
  textAlign(CENTER, TOP);
  fill(80, 200, 255);
  text("x(t)", 0, 0);
  popMatrix();

  pushMatrix();
  translate(px1+51, (py0+py1)/2);
  rotate(-HALF_PI);
  textAlign(CENTER, TOP);
  fill(255, 170, 80);
  text("y(t)", 0, -10);
  popMatrix();

  textAlign(LEFT, BASELINE);
  drawPanelFrame(gx, gy, gwFrame, gh);
}

// ======================================================
// GRÀFIC θ(t), ω(t) (pèndol simple)
// ======================================================
void drawAngleGraph(float gx, float gy, float gw, float gh) {
  float gwFrame = gw + 15;
  noStroke();
  fill(25);
  rect(gx, gy, gwFrame, gh, 10);

  int n = angFilled ? angHistoryN : angIndex;
  if (n < 2) {
    fill(230);
    textSize(12);
    text("θ(t), ω(t) (esperant dades...)", gx+10, gy+10);
    drawPanelFrame(gx, gy, gwFrame, gh);
    return;
  }

  float px0 = gx + plotPadL + plotFramePadX + plotShiftX;
  float px1 = gx + gwFrame - plotPadR - 24 - plotFramePadX + plotShiftX;
  float py0 = gy + plotPadT;
  float py1 = gy + gh - plotPadB;

  float tMin = Float.POSITIVE_INFINITY, tMax = Float.NEGATIVE_INFINITY;
  float thMin = Float.POSITIVE_INFINITY, thMax = Float.NEGATIVE_INFINITY;
  float wMin = Float.POSITIVE_INFINITY, wMax = Float.NEGATIVE_INFINITY;
  for (int i = 0; i < n; i++) {
    int idx = angFilled ? (angIndex + i) % angHistoryN : i;
    float tt = tAngBuf[idx];
    float thv = thBuf[idx];
    float wv = wBuf[idx];
    tMin = min(tMin, tt);
    tMax = max(tMax, tt);
    thMin = min(thMin, thv);
    thMax = max(thMax, thv);
    wMin = min(wMin, wv);
    wMax = max(wMax, wv);
  }
  if (tMax - tMin < 1e-9) tMax = tMin + 1;
  if (thMax - thMin < 1e-9) { thMax = thMin + 1; thMin -= 1; }
  if (wMax - wMin < 1e-9) { wMax = wMin + 1; wMin -= 1; }

  strokeWeight(1);
  stroke(120);
  line(px0, py0, px0, py1);
  line(px1, py0, px1, py1);
  line(px0, py1, px1, py1);

  int xticks = 5;
  fill(230);
  textSize(10);
  for (int k = 0; k <= xticks; k++) {
    float tt = lerp(tMin, tMax, k/(float)xticks);
    float x = map(tt, tMin, tMax, px0, px1);
    stroke(120);
    line(x, py1, x, py1+4);
    noStroke();
    textAlign(CENTER, TOP);
    text(nf(tt, 0, 1), x, py1+6);
  }

  int yticks = 4;
  for (int k = 0; k <= yticks; k++) {
    float val = lerp(thMin, thMax, k/(float)yticks);
    float y = map(val, thMax, thMin, py0, py1);
    stroke(120);
    line(px0-4, y, px0, y);
    noStroke();
    textAlign(RIGHT, CENTER);
    text(nf(val, 0, 2), px0-6, y);
  }
  for (int k = 0; k <= yticks; k++) {
    float val = lerp(wMin, wMax, k/(float)yticks);
    float y = map(val, wMax, wMin, py0, py1);
    stroke(120);
    line(px1, y, px1+4, y);
    noStroke();
    textAlign(LEFT, CENTER);
    text(nf(val, 0, 2), px1+6, y);
  }
  textAlign(LEFT, BASELINE);

  stroke(80, 200, 255);
  strokeWeight(1.2);
  noFill();
  beginShape();
  for (int i = 0; i < n; i++) {
    int idx = angFilled ? (angIndex + i) % angHistoryN : i;
    float x = map(tAngBuf[idx], tMin, tMax, px0, px1);
    float y = map(thBuf[idx], thMax, thMin, py0, py1);
    vertex(x, y);
  }
  endShape();

  stroke(255, 170, 80);
  strokeWeight(1.2);
  beginShape();
  for (int i = 0; i < n; i++) {
    int idx = angFilled ? (angIndex + i) % angHistoryN : i;
    float x = map(tAngBuf[idx], tMin, tMax, px0, px1);
    float y = map(wBuf[idx], wMax, wMin, py0, py1);
    vertex(x, y);
  }
  endShape();

  fill(230);
  textSize(12);
  textAlign(LEFT, BASELINE);
  text("θ(t), ω(t)", gx+10, gy-10);

  textSize(10);
  textAlign(RIGHT, TOP);
  text("t", px1, py1+16);

  pushMatrix();
  translate(gx+6, (py0+py1)/2);
  rotate(-HALF_PI);
  textAlign(CENTER, TOP);
  fill(80, 200, 255);
  text("θ(t)", 0, 0);
  popMatrix();

  pushMatrix();
  translate(px1+46, (py0+py1)/2);
  rotate(-HALF_PI);
  textAlign(CENTER, TOP);
  fill(255, 170, 80);
  text("ω(t)", 0, -10);
  popMatrix();

  textAlign(LEFT, BASELINE);
  drawPanelFrame(gx, gy, gwFrame, gh);
}

void drawXYSpectrum(float gx, float gy, float gw, float gh) {
  if (spectrumFrozen && specN > 0) {
    drawXYSpectrumFrozen(gx, gy, gw, gh);
    return;
  }
  float gwFrame = gw + 15;
  noStroke();
  fill(25);
  rect(gx, gy, gwFrame, gh, 10);

  int nAvail = xyFilled ? xyHistoryN : xyIndex;
  int n = min(nAvail, spectrumHistoryN);
  if (n < 8) {
    fill(230);
    textSize(12);
    text("Espectre x(t), y(t) (esperant dades...)", gx+10, gy+10);
    drawPanelFrame(gx, gy, gwFrame, gh);
    return;
  }

  float px0 = gx + plotPadL + plotFramePadX + plotShiftX;
  float px1 = gx + gwFrame - plotPadR - 24 - plotFramePadX + plotShiftX;
  float py0 = gy + plotPadT;
  float py1 = gy + gh - plotPadB;

  for (int i = 0; i < n; i++) {
    int idx;
    if (xyFilled) idx = (xyIndex + (nAvail - n) + i) % xyHistoryN;
    else idx = i;
    fftX[i] = xBuf[idx];
    fftY[i] = yBuf[idx];
    fftT[i] = tXYBuf[idx];
  }

  float dtSum = 0;
  for (int i = 0; i < n-1; i++) dtSum += (fftT[i+1] - fftT[i]);
  float dtAvg = dtSum / max(1, n-1);
  if (dtAvg <= 1e-6) dtAvg = dt;
  float fNyq = 0.5 / dtAvg;
  lastFNyq = fNyq;

  float fMinDisplay = max(0.0, spectrumFMin);
  float fMaxDisplay = max(fMinDisplay + 1e-6, fNyq);
  float fRangeDisplay = fMaxDisplay - fMinDisplay;

  int nFFT = 1;
  while (nFFT * 2 <= n) nFFT *= 2;
  int kMaxFFT = nFFT / 2;
  int kMaxPlot = max(2, min(spectrumFreqPoints, specX.length));
  if (!spectrumUseDFT) kMaxPlot = min(kMaxPlot, kMaxFFT);

  boolean doUpdateSpectrum = (xySamplesTotal - lastSpectrumSamples) >= spectrumEveryPoints || lastSpectrumSamples == 0;
  if (doUpdateSpectrum) lastSpectrumSamples = xySamplesTotal;

  if (doUpdateSpectrum && spectrumUseDFT) {
    for (int k = 0; k < kMaxPlot; k++) {
      float ff = fMinDisplay + fRangeDisplay * (k / (float)(kMaxPlot - 1));
      if (ff > fNyq) {
        specX[k] = 0;
        specY[k] = 0;
        continue;
      }
      float reX = 0, imX = 0, reY = 0, imY = 0;
      for (int j = 0; j < n; j++) {
        float w = 0.5 - 0.5 * cos(TWO_PI * j / (n - 1));
        float ang = TWO_PI * ff * j * dtAvg;
        float ca = cos(ang);
        float sa = sin(ang);
        float x = fftX[j] * w;
        float y = fftY[j] * w;
        reX += x * ca;
        imX -= x * sa;
        reY += y * ca;
        imY -= y * sa;
      }
      specX[k] = sqrt(reX*reX + imX*imX) / n;
      specY[k] = sqrt(reY*reY + imY*imY) / n;
    }
  } else if (doUpdateSpectrum) {
    int start = max(0, n - nFFT);
    for (int i = 0; i < nFFT; i++) {
      float w = 0.5 - 0.5 * cos(TWO_PI * i / (nFFT - 1));
      fftX[i] = fftX[start + i] * w;
      fftY[i] = fftY[start + i] * w;
      fftImX[i] = 0;
      fftImY[i] = 0;
    }
    fftRadix2(fftX, fftImX, nFFT);
    fftRadix2(fftY, fftImY, nFFT);
    for (int k = 0; k < kMaxPlot; k++) {
      float ff = fMinDisplay + fRangeDisplay * (k / (float)(kMaxPlot - 1));
      if (ff > fNyq) {
        specX[k] = 0;
        specY[k] = 0;
        continue;
      }
      float bin = ff * (kMaxFFT / fNyq);
      int k0 = constrain((int)floor(bin), 0, kMaxFFT);
      int k1 = min(k0 + 1, kMaxFFT);
      float t = bin - k0;
      float reX0 = fftX[k0];
      float imX0 = fftImX[k0];
      float reY0 = fftY[k0];
      float imY0 = fftImY[k0];
      float magX0 = sqrt(reX0*reX0 + imX0*imX0) / nFFT;
      float magY0 = sqrt(reY0*reY0 + imY0*imY0) / nFFT;
      if (k1 == k0) {
        specX[k] = magX0;
        specY[k] = magY0;
      } else {
        float reX1 = fftX[k1];
        float imX1 = fftImX[k1];
        float reY1 = fftY[k1];
        float imY1 = fftImY[k1];
        float magX1 = sqrt(reX1*reX1 + imX1*imX1) / nFFT;
        float magY1 = sqrt(reY1*reY1 + imY1*imY1) / nFFT;
        specX[k] = lerp(magX0, magX1, t);
        specY[k] = lerp(magY0, magY1, t);
      }
    }
  }

  float maxX = 1e-9;
  float maxY = 1e-9;
  float minX = Float.POSITIVE_INFINITY;
  float minY = Float.POSITIVE_INFINITY;
  for (int k = 0; k < kMaxPlot; k++) {
    maxX = max(maxX, specX[k]);
    maxY = max(maxY, specY[k]);
    if (specX[k] > 0) minX = min(minX, specX[k]);
    if (specY[k] > 0) minY = min(minY, specY[k]);
  }
  if (!Float.isFinite(minX)) minX = maxX * 1e-3;
  if (!Float.isFinite(minY)) minY = maxY * 1e-3;
  minX = min(minX, maxX * 0.1);
  minY = min(minY, maxY * 0.1);
  if (minX < 1e-12) minX = 1e-12;
  if (minY < 1e-12) minY = 1e-12;

  float logMinX = log(minX);
  float logMaxX = log(maxX);
  float logMinY = log(minY);
  float logMaxY = log(maxY);

  float fMinLog = (fMinDisplay > 0)
    ? max(1e-6, fMinDisplay)
    : max(1e-3, fMaxDisplay * 1e-3);
  float logFMin = log(fMinLog);
  float logFMax = log(max(fMinLog * 1.000001, fMaxDisplay));

  strokeWeight(1);
  stroke(120);
  line(px0, py0, px0, py1);
  line(px1, py0, px1, py1);
  line(px0, py1, px1, py1);

  int xticks = max(2, spectrumXTicks);
  fill(230);
  textSize(10);
  stroke(120);
  if (spectrumLogF) {
    int logTicks = xticks;
    int logDen = max(1, logTicks - 1);
    for (int k = 0; k < logTicks; k++) {
      float ff = exp(lerp(logFMin, logFMax, k/(float)logDen));
      float x = map(log(ff), logFMin, logFMax, px0, px1);
      stroke(120);
      line(x, py1, x, py1+4);
      noStroke();
      textAlign(CENTER, TOP);
      String label = ff < 1 ? nf(ff, 0, 3) : nf(ff, 0, 2);
      text(label, x, py1+6);
    }
  } else {
    for (int k = 0; k < xticks; k++) {
      float ff = lerp(fMinDisplay, fMaxDisplay, k/(float)(xticks - 1));
      float x = map(ff, fMinDisplay, fMaxDisplay, px0, px1);
      stroke(120);
      line(x, py1, x, py1+4);
      noStroke();
      textAlign(CENTER, TOP);
      text(nf(ff, 0, 2), x, py1+6);
    }
  }

  int yticks = 4;
  if (spectrumLogY) {
    for (int k = 0; k <= yticks; k++) {
      float lv = lerp(logMinX, logMaxX, k/(float)yticks);
      float val = exp(lv);
      float y = map(lv, logMaxX, logMinX, py0, py1);
      stroke(120);
      line(px0-4, y, px0, y);
      noStroke();
      textAlign(RIGHT, CENTER);
      text(fmtSci(val), px0-6, y);
    }
    for (int k = 0; k <= yticks; k++) {
      float lv = lerp(logMinY, logMaxY, k/(float)yticks);
      float val = exp(lv);
      float y = map(lv, logMaxY, logMinY, py0, py1);
      stroke(120);
      line(px1, y, px1+4, y);
      noStroke();
      textAlign(LEFT, CENTER);
      text(fmtSci(val), px1+6, y);
    }
  } else {
    for (int k = 0; k <= yticks; k++) {
      float val = (k/(float)yticks) * maxX;
      float y = map(val, maxX, 0, py0, py1);
      stroke(120);
      line(px0-4, y, px0, y);
      noStroke();
      textAlign(RIGHT, CENTER);
      text(fmtSci(val), px0-6, y);
    }
    for (int k = 0; k <= yticks; k++) {
      float val = (k/(float)yticks) * maxY;
      float y = map(val, maxY, 0, py0, py1);
      stroke(120);
      line(px1, y, px1+4, y);
      noStroke();
      textAlign(LEFT, CENTER);
      text(fmtSci(val), px1+6, y);
    }
  }
  textAlign(LEFT, BASELINE);

  stroke(80, 200, 255);
  strokeWeight(1.2);
  noFill();
  beginShape();
  for (int k = 0; k < kMaxPlot; k++) {
    float ff = fMinDisplay + fRangeDisplay * (k / (float)(kMaxPlot - 1));
    float x = spectrumLogF
            ? (ff <= 0 ? px0 : map(log(max(ff, fMinLog)), logFMin, logFMax, px0, px1))
            : map(ff, fMinDisplay, fMaxDisplay, px0, px1);
    float y = spectrumLogY
            ? map(log(max(specX[k], minX)), logMaxX, logMinX, py0, py1)
            : map(specX[k], maxX, 0, py0, py1);
    vertex(x, y);
  }
  endShape();

  stroke(255, 170, 80);
  strokeWeight(1.2);
  beginShape();
  for (int k = 0; k < kMaxPlot; k++) {
    float ff = fMinDisplay + fRangeDisplay * (k / (float)(kMaxPlot - 1));
    float x = spectrumLogF
            ? (ff <= 0 ? px0 : map(log(max(ff, fMinLog)), logFMin, logFMax, px0, px1))
            : map(ff, fMinDisplay, fMaxDisplay, px0, px1);
    float y = spectrumLogY
            ? map(log(max(specY[k], minY)), logMaxY, logMinY, py0, py1)
            : map(specY[k], maxY, 0, py0, py1);
    vertex(x, y);
  }
  endShape();

  fill(230);
  textSize(12);
  textAlign(LEFT, BASELINE);
  text(spectrumUseDFT ? "Espectre x(t), y(t) (DFT)" : "Espectre x(t), y(t) (FFT)", gx+10, gy-10);

  textSize(10);
  textAlign(RIGHT, TOP);
  text(spectrumLogF ? "f (Hz)" : "f", px1, py1+16);

  pushMatrix();
  translate(gx+16, (py0+py1)/2);
  rotate(-HALF_PI);
  textAlign(CENTER, TOP);
  fill(80, 200, 255);
  text("|X(f)|", 0, -10);
  popMatrix();

  pushMatrix();
  translate(px1+41, (py0+py1)/2);
  rotate(-HALF_PI);
  textAlign(CENTER, TOP);
  fill(255, 170, 80);
  text("|Y(f)|", 0, 0);
  popMatrix();

  textAlign(LEFT, BASELINE);
  drawPanelFrame(gx, gy, gwFrame, gh);
}

void drawXYSpectrumFrozen(float gx, float gy, float gw, float gh) {
  float gwFrame = gw + 15;
  noStroke();
  fill(25);
  rect(gx, gy, gwFrame, gh, 10);

  int n = specN;
  if (n < 8) {
    fill(230);
    textSize(12);
    text("Espectre x(t), y(t) (esperant dades...)", gx+10, gy+10);
    drawPanelFrame(gx, gy, gwFrame, gh);
    return;
  }

  float px0 = gx + plotPadL + plotFramePadX + plotShiftX;
  float px1 = gx + gwFrame - plotPadR - 24 - plotFramePadX + plotShiftX;
  float py0 = gy + plotPadT;
  float py1 = gy + gh - plotPadB;

  float fMinDisplay = max(0.0, spectrumFMin);
  float fMaxDisplay = max(fMinDisplay + 1e-6, max(lastFNyq, fMinDisplay + 1e-6));
  float fRangeDisplay = fMaxDisplay - fMinDisplay;

  float maxX = 1e-9;
  float maxY = 1e-9;
  float minX = Float.POSITIVE_INFINITY;
  float minY = Float.POSITIVE_INFINITY;
  for (int k = 0; k < n; k++) {
    maxX = max(maxX, specX[k]);
    maxY = max(maxY, specY[k]);
    if (specX[k] > 0) minX = min(minX, specX[k]);
    if (specY[k] > 0) minY = min(minY, specY[k]);
  }
  if (!Float.isFinite(minX)) minX = maxX * 1e-3;
  if (!Float.isFinite(minY)) minY = maxY * 1e-3;
  minX = min(minX, maxX * 0.1);
  minY = min(minY, maxY * 0.1);
  if (minX < 1e-12) minX = 1e-12;
  if (minY < 1e-12) minY = 1e-12;

  float logMinX = log(minX);
  float logMaxX = log(maxX);
  float logMinY = log(minY);
  float logMaxY = log(maxY);

  float fMinLog = (fMinDisplay > 0)
    ? max(1e-6, fMinDisplay)
    : max(1e-3, fMaxDisplay * 1e-3);
  float logFMin = log(fMinLog);
  float logFMax = log(max(fMinLog * 1.000001, fMaxDisplay));

  strokeWeight(1);
  stroke(120);
  line(px0, py0, px0, py1);
  line(px1, py0, px1, py1);
  line(px0, py1, px1, py1);

  int xticks = max(2, spectrumXTicks);
  fill(230);
  textSize(10);
  stroke(120);
  if (spectrumLogF) {
    int logTicks = xticks;
    int logDen = max(1, logTicks - 1);
    for (int k = 0; k < logTicks; k++) {
      float ff = exp(lerp(logFMin, logFMax, k/(float)logDen));
      float x = map(log(ff), logFMin, logFMax, px0, px1);
      stroke(120);
      line(x, py1, x, py1+4);
      noStroke();
      textAlign(CENTER, TOP);
      String label = ff < 1 ? nf(ff, 0, 3) : nf(ff, 0, 2);
      text(label, x, py1+6);
    }
  } else {
    for (int k = 0; k < xticks; k++) {
      float ff = lerp(fMinDisplay, fMaxDisplay, k/(float)(xticks - 1));
      float x = map(ff, fMinDisplay, fMaxDisplay, px0, px1);
      stroke(120);
      line(x, py1, x, py1+4);
      noStroke();
      textAlign(CENTER, TOP);
      text(nf(ff, 0, 2), x, py1+6);
    }
  }

  int yticks = 4;
  if (spectrumLogY) {
    for (int k = 0; k <= yticks; k++) {
      float lv = lerp(logMinX, logMaxX, k/(float)yticks);
      float val = exp(lv);
      float y = map(lv, logMaxX, logMinX, py0, py1);
      stroke(120);
      line(px0-4, y, px0, y);
      noStroke();
      textAlign(RIGHT, CENTER);
      text(fmtSci(val), px0-6, y);
    }
    for (int k = 0; k <= yticks; k++) {
      float lv = lerp(logMinY, logMaxY, k/(float)yticks);
      float val = exp(lv);
      float y = map(lv, logMaxY, logMinY, py0, py1);
      stroke(120);
      line(px1, y, px1+4, y);
      noStroke();
      textAlign(LEFT, CENTER);
      text(fmtSci(val), px1+6, y);
    }
  } else {
    for (int k = 0; k <= yticks; k++) {
      float val = lerp(0, maxX, k/(float)yticks);
      float y = map(val, maxX, 0, py0, py1);
      stroke(120);
      line(px0-4, y, px0, y);
      noStroke();
      textAlign(RIGHT, CENTER);
      text(nf(val, 0, 3), px0-6, y);
    }
    for (int k = 0; k <= yticks; k++) {
      float val = lerp(0, maxY, k/(float)yticks);
      float y = map(val, maxY, 0, py0, py1);
      stroke(120);
      line(px1, y, px1+4, y);
      noStroke();
      textAlign(LEFT, CENTER);
      text(nf(val, 0, 3), px1+6, y);
    }
  }

  if (spectrumLogF) {
    stroke(80, 200, 255);
    strokeWeight(0.9);
    noFill();
    beginShape();
    for (int k = 0; k < n; k++) {
      float ff = specF[k];
      float ffPlot = max(ff, fMinLog);
      float x = map(log(ffPlot), logFMin, logFMax, px0, px1);
      float y = spectrumLogY
        ? map(log(max(specX[k], minX)), logMaxX, logMinX, py0, py1)
        : map(specX[k], maxX, 0, py0, py1);
      vertex(x, y);
    }
    endShape();

    stroke(255, 170, 80);
    strokeWeight(0.9);
    beginShape();
    for (int k = 0; k < n; k++) {
      float ff = specF[k];
      float ffPlot = max(ff, fMinLog);
      float x = map(log(ffPlot), logFMin, logFMax, px0, px1);
      float y = spectrumLogY
        ? map(log(max(specY[k], minY)), logMaxY, logMinY, py0, py1)
        : map(specY[k], maxY, 0, py0, py1);
      vertex(x, y);
    }
    endShape();
  } else {
    stroke(80, 200, 255);
    strokeWeight(1.2);
    noFill();
    beginShape();
    for (int k = 0; k < n; k++) {
      float ff = specF[k];
      float x = map(ff, fMinDisplay, fMaxDisplay, px0, px1);
      float y = spectrumLogY
        ? map(log(max(specX[k], minX)), logMaxX, logMinX, py0, py1)
        : map(specX[k], maxX, 0, py0, py1);
      vertex(x, y);
    }
    endShape();

    stroke(255, 170, 80);
    strokeWeight(1.2);
    beginShape();
    for (int k = 0; k < n; k++) {
      float ff = specF[k];
      float x = map(ff, fMinDisplay, fMaxDisplay, px0, px1);
      float y = spectrumLogY
        ? map(log(max(specY[k], minY)), logMaxY, logMinY, py0, py1)
        : map(specY[k], maxY, 0, py0, py1);
      vertex(x, y);
    }
    endShape();
  }

  fill(230);
  textSize(12);
  text("Espectre x(t), y(t) (" + (spectrumUseDFT ? "DFT" : "FFT") + ")", gx+10, gy-10);

  textSize(10);
  textAlign(RIGHT, TOP);
  text(spectrumLogF ? "f (Hz)" : "f", px1, py1+16);

  pushMatrix();
  translate(gx+16, (py0+py1)/2);
  rotate(-HALF_PI);
  textAlign(CENTER, TOP);
  fill(80, 200, 255);
  text("|X(f)|", 0, -10);
  popMatrix();

  pushMatrix();
  translate(px1+41, (py0+py1)/2);
  rotate(-HALF_PI);
  textAlign(CENTER, TOP);
  fill(255, 170, 80);
  text("|Y(f)|", 0, 0);
  popMatrix();

  textAlign(LEFT, BASELINE);
  drawPanelFrame(gx, gy, gwFrame, gh);
}

// ======================================================
// PANELL trajectòria TOTAL (PGraphics) + eixos numerats
// ARA (x,y) són FÍSICS (unitats de longitud), no píxels
// ======================================================
void drawTrajectoryPanel() {
  noStroke();
  fill(25);
  rect(trajGX, trajGY, trajGW + 15, trajGH, 10);

  image(trajLayer, trajGX, trajGY);

  float px0 = trajGX + plotPadL + plotFramePadX + plotShiftX;
  float px1 = trajGX + trajGW + 15 - plotPadR - plotFramePadX + plotShiftX;
  float py0 = trajGY + plotPadT;
  float py1 = trajGY + trajGH - plotPadB;

  float xmin, xmax, ymin, ymax;
  if (trajViewActive && trajBoundsInit) {
    xmin = trajViewMinX; xmax = trajViewMaxX;
    ymin = trajViewMinY; ymax = trajViewMaxY;
  } else {
    float R = isDouble ? (L1 + L2) : L1;
    xmin = -R; xmax = R;
    ymin = -R; ymax = R;
  }

  strokeWeight(1);
  stroke(120);
  line(px0, py0, px0, py1);
  line(px0, py1, px1, py1);

  int xticks = 4;
  fill(230);
  textSize(10);
  for (int k = 0; k <= xticks; k++) {
    float xw = lerp(xmin, xmax, k/(float)xticks);
    float x = map(xw, xmin, xmax, px0, px1);
    stroke(120);
    line(x, py1, x, py1+4);
    noStroke();
    textAlign(CENTER, TOP);
    text(nf(xw, 0, 2), x, py1+6);
  }

  int yticks = 4;
  for (int k = 0; k <= yticks; k++) {
    float yw = lerp(ymin, ymax, k/(float)yticks);
    float y = map(yw, ymin, ymax, py0, py1);
    stroke(120);
    line(px0-4, y, px0, y);
    noStroke();
    textAlign(RIGHT, CENTER);
    text(nf(yw, 0, 2), px0-6, y);
  }

  fill(230);
  textSize(12);
  textAlign(LEFT, BASELINE);
  text("Trajectòria XY", trajGX + 10, trajGY-10);

  textSize(10);
  textAlign(RIGHT, TOP);
  fill(230);
  text("x", px1, py1+16);

  pushMatrix();
  translate(trajGX+16, (py0+py1)/2);
  rotate(-HALF_PI);
  textAlign(CENTER, TOP);
  fill(230);
  text("y", 0, 0);
  popMatrix();

  textAlign(LEFT, BASELINE);

  drawPanelFrame(trajGX, trajGY, trajGW + 15, trajGH);
}

void drawPanelFrame(float x, float y, float w, float h) {
  stroke(240);
  strokeWeight(frameW);
  strokeJoin(ROUND);
  noFill();
  rect(x, y, w, h, 10);
}

void fftRadix2(float[] re, float[] im, int n) {
  int j = 0;
  for (int i = 1; i < n; i++) {
    int bit = n >> 1;
    while (j >= bit) { j -= bit; bit >>= 1; }
    j += bit;
    if (i < j) {
      float tr = re[i]; re[i] = re[j]; re[j] = tr;
      float ti = im[i]; im[i] = im[j]; im[j] = ti;
    }
  }

  for (int len = 2; len <= n; len <<= 1) {
    float ang = -TWO_PI / len;
    float wlenRe = cos(ang);
    float wlenIm = sin(ang);
    for (int i = 0; i < n; i += len) {
      float wRe = 1;
      float wIm = 0;
      for (int k = 0; k < len/2; k++) {
        int u = i + k;
        int v = u + len/2;
        float vr = re[v] * wRe - im[v] * wIm;
        float vi = re[v] * wIm + im[v] * wRe;
        re[v] = re[u] - vr;
        im[v] = im[u] - vi;
        re[u] += vr;
        im[u] += vi;
        float nextRe = wRe * wlenRe - wIm * wlenIm;
        wIm = wRe * wlenIm + wIm * wlenRe;
        wRe = nextRe;
      }
    }
  }
}

PVector worldToTrajLayer(float xPhys, float yPhys) {
  float xmin, xmax, ymin, ymax;
  if (trajViewActive && trajBoundsInit) {
    xmin = trajViewMinX; xmax = trajViewMaxX;
    ymin = trajViewMinY; ymax = trajViewMaxY;
  } else {
    float Rphys = isDouble ? (L1 + L2) : L1;
    xmin = -Rphys; xmax = Rphys;
    ymin = -Rphys; ymax = Rphys;
  }

  float px0 = plotPadL + plotFramePadX + plotShiftX;
  float px1 = trajGW + 15 - plotPadR - plotFramePadX + plotShiftX;
  float py0 = plotPadT;
  float py1 = trajGH - plotPadB;

  float px = map(xPhys, xmin, xmax, px0, px1);
  float py = map(yPhys, ymin, ymax, py0, py1);

  return new PVector(px, py);
}

void autoscaleTrajectory() {
  int n = trajFilled ? trajHistoryN : trajIndex;
  if (n < 2 || !trajBoundsInit) return;

  float xmin = trajMinX;
  float xmax = trajMaxX;
  float ymin = trajMinY;
  float ymax = trajMaxY;

  float cx = 0.5 * (xmin + xmax);
  float cy = 0.5 * (ymin + ymax);
  float range = max(xmax - xmin, ymax - ymin);
  if (range < 1e-6) range = 1e-6;
  range *= 1.1;

  trajViewMinX = cx - range*0.5;
  trajViewMaxX = cx + range*0.5;
  trajViewMinY = cy - range*0.5;
  trajViewMaxY = cy + range*0.5;
  trajViewActive = true;

  redrawTrajectoryLayer();
}

void redrawTrajectoryLayer() {
  trajLayer.beginDraw();
  trajLayer.background(25);
  trajLayer.endDraw();
  trajHasPrev = false;
  trajPrevX = 0;
  trajPrevY = 0;

  int n = trajFilled ? trajHistoryN : trajIndex;
  for (int i = 0; i < n; i++) {
    int idx = trajFilled ? (trajIndex + i) % trajHistoryN : i;
    PVector p = worldToTrajLayer(trajXBuf[idx], trajYBuf[idx]);

    trajLayer.beginDraw();
    trajLayer.noFill();

    trajLayer.stroke(255, 255, 0, 22);
    trajLayer.strokeWeight(trajGlowW);
    if (trajHasPrev) trajLayer.line(trajPrevX, trajPrevY, p.x, p.y);
    else trajLayer.point(p.x, p.y);

    trajLayer.stroke(255, 255, 0, 170);
    trajLayer.strokeWeight(trajLineW);
    if (trajHasPrev) trajLayer.line(trajPrevX, trajPrevY, p.x, p.y);
    else trajLayer.point(p.x, p.y);

    trajLayer.endDraw();
    trajPrevX = p.x;
    trajPrevY = p.y;
    trajHasPrev = true;
  }
}

void addToTrajectoryLayer(float xPhys, float yPhys) {
  trajXBuf[trajIndex] = xPhys;
  trajYBuf[trajIndex] = yPhys;
  trajIndex++;
  if (trajIndex >= trajHistoryN) { trajIndex = 0; trajFilled = true; }

  if (!trajBoundsInit) {
    trajMinX = trajMaxX = xPhys;
    trajMinY = trajMaxY = yPhys;
    trajBoundsInit = true;
  } else {
    trajMinX = min(trajMinX, xPhys);
    trajMaxX = max(trajMaxX, xPhys);
    trajMinY = min(trajMinY, yPhys);
    trajMaxY = max(trajMaxY, yPhys);
  }

  PVector p = worldToTrajLayer(xPhys, yPhys);

  trajLayer.beginDraw();
  trajLayer.noFill();

  trajLayer.stroke(255, 255, 0, 22);
  trajLayer.strokeWeight(trajGlowW);
  if (trajHasPrev) trajLayer.line(trajPrevX, trajPrevY, p.x, p.y);
  else trajLayer.point(p.x, p.y);

  trajLayer.stroke(255, 255, 0, 170);
  trajLayer.strokeWeight(trajLineW);
  if (trajHasPrev) trajLayer.line(trajPrevX, trajPrevY, p.x, p.y);
  else trajLayer.point(p.x, p.y);

  trajLayer.endDraw();

  trajPrevX = p.x;
  trajPrevY = p.y;
  trajHasPrev = true;
}

void clearTrajectoryLayer() {
  trajLayer.beginDraw();
  trajLayer.background(25);
  trajLayer.endDraw();
  trajHasPrev = false;
  trajIndex = 0;
  trajFilled = false;
  trajBoundsInit = false;
  trajViewActive = false;
}

// ======================================================
// RESET ~E0 (com abans)
// ======================================================
float solveOmegaSimpleForEnergy(float th, float targetE, float wRef) {
  float V = -m1 * g * L1 * cos(th);
  float K = targetE - V;
  if (K < 0) K = 0;
  float wAbs = sqrt((2.0 * K) / (m1 * L1 * L1));
  return (wRef >= 0) ? wAbs : -wAbs;
}

float solveW2ForEnergyDouble(float th1p, float w1p, float th2p, float targetE, float w2Ref) {
  float delta = th1p - th2p;

  float V =
    -(m1 + m2) * g * L1 * cos(th1p)
    - m2 * g * L2 * cos(th2p);

  float Tconst = 0.5 * (m1 + m2) * (L1*L1) * (w1p*w1p);

  float a = 0.5 * m2 * (L2*L2);
  float b = m2 * L1 * L2 * w1p * cos(delta);
  float c = V + Tconst - targetE;

  float disc = b*b - 4*a*c;
  if (disc < 0) disc = 0;

  float sqrtDisc = sqrt(disc);
  float w2r1 = (-b + sqrtDisc) / (2*a);
  float w2r2 = (-b - sqrtDisc) / (2*a);

  return (abs(w2r1 - w2Ref) < abs(w2r2 - w2Ref)) ? w2r1 : w2r2;
}

void applyResetCommon() {
  time = 0;
  stepCounter = 0;

  updateEnergyMonitor();

  for (int i = 0; i < trailLength; i++) trail[i] = null;
  trailIndex = 0;

  for (int i = 0; i < xyHistoryN; i++) { tXYBuf[i]=0; xBuf[i]=0; yBuf[i]=0; }
  xyIndex = 0; xyFilled = false;
  xySamplesTotal = 0;
  lastSpectrumSamples = 0;
  tAll.clear();
  xAll.clear();
  yAll.clear();
  spectrumFrozen = false;
  specN = 0;
  tAll.clear();
  xAll.clear();
  yAll.clear();
  spectrumFrozen = false;
  specN = 0;

  for (int i = 0; i < angHistoryN; i++) { tAngBuf[i]=0; thBuf[i]=0; wBuf[i]=0; }
  angIndex = 0; angFilled = false;

  trajHasPrev = false;
}

void resetPerturbedAnglesSameEnergy() {
  float eps = 1e-3;

  if (!isDouble) {
    float th = baseTh1 + random(-eps, eps);
    float w  = solveOmegaSimpleForEnergy(th, E0, baseW1);

    th1 = th; w1 = w;
    th2 = 0;  w2 = 0;

    applyResetCommon();
  } else {
    float th1p = baseTh1 + random(-eps, eps);
    float th2p = baseTh2 + random(-eps, eps);
    float w1p  = baseW1;

    float w2p = solveW2ForEnergyDouble(th1p, w1p, th2p, E0, baseW2);

    th1 = th1p; th2 = th2p;
    w1  = w1p;  w2  = w2p;

    applyResetCommon();
  }
}

void resetPerturbedParamsSameEnergy() {
  float epsL = 0.003;
  float epsM = 0.005;
  float epsA = 1e-3;

  m1 = max(1e-6, baseM1 * (1.0 + random(-epsM, epsM)));
  if (isDouble) m2 = max(1e-6, baseM2 * (1.0 + random(-epsM, epsM)));

  L1 = max(1e-6, baseL1 * (1.0 + random(-epsL, epsL)));
  if (isDouble) L2 = max(1e-6, baseL2 * (1.0 + random(-epsL, epsL)));

  g = max(1e-6, baseG * (1.0 + random(-epsL, epsL)));

  // reflecteix en sliders
  sM1.value = m1; sM2.value = m2; sL1.value = L1; sL2.value = L2; sG.value = g;

  computeDrawScale();

  if (!isDouble) {
    float th = baseTh1 + random(-epsA, epsA);
    float w  = solveOmegaSimpleForEnergy(th, E0, baseW1);

    th1 = th; w1 = w;
    th2 = 0;  w2 = 0;

    applyResetCommon();
  } else {
    float th1p = baseTh1 + random(-epsA, epsA);
    float th2p = baseTh2 + random(-epsA, epsA);
    float w1p  = baseW1;

    float w2p = solveW2ForEnergyDouble(th1p, w1p, th2p, E0, baseW2);

    th1 = th1p; th2 = th2p;
    w1  = w1p;  w2  = w2p;

    applyResetCommon();
  }
}

void resetAllToInitial() {
  paused = false;

  physicsStepsPerFrame = initPhysicsStepsPerFrame;
  subSteps = initSubSteps;
  dt = initDt;

  showSpectrum = initShowSpectrum;
  spectrumLogY = initSpectrumLogY;
  spectrumUseDFT = initSpectrumUseDFT;
  spectrumFMin = initSpectrumFMin;
  spectrumFreqPoints = initSpectrumFreqPoints;
  spectrumLogF = initSpectrumLogF;
  spectrumXTicks = initSpectrumXTicks;
  spectrumEveryPoints = initSpectrumEveryPoints;

  m1 = initM1;
  m2 = initM2;
  L1 = initL1;
  L2 = initL2;
  g  = initG;

  initTh1 = radians(sTh1.value);
  initTh2 = radians(sTh2.value);

  switchMode(initIsDouble);

  th1 = initTh1;
  th2 = initTh2;
  w1  = initW1;
  w2  = initW2;

  baseTh1 = th1; baseTh2 = th2;
  baseW1  = w1;  baseW2  = w2;
  E0 = energyTotal();
  updateEnergyMonitor();

  sTh1.value = degrees(initTh1);
  sTh2.value = degrees(initTh2);

  // neteja tots els històrics
  clearTrajectoryLayer();
  for (int i = 0; i < trailLength; i++) trail[i] = null;
  trailIndex = 0;

  for (int i = 0; i < xyHistoryN; i++) { tXYBuf[i]=0; xBuf[i]=0; yBuf[i]=0; }
  xyIndex = 0; xyFilled = false;
  xySamplesTotal = 0;
  lastSpectrumSamples = 0;
  tAll.clear();
  xAll.clear();
  yAll.clear();
  spectrumFrozen = false;
  specN = 0;

  for (int i = 0; i < angHistoryN; i++) { tAngBuf[i]=0; thBuf[i]=0; wBuf[i]=0; }
  angIndex = 0; angFilled = false;

  time = 0;
  stepCounter = 0;

  updateSpectrumButtonLabel();
}

// ======================================================
// DINÀMICA (RK4) mode-dependent
// ======================================================
float[] derivsSimple(float th, float w) {
  float dth = w;
  float dw  = -(g / L1) * sin(th);
  return new float[] { dth, dw };
}

float[] derivsDouble(float th1, float w1, float th2, float w2) {
  float dth1 = w1;
  float dth2 = w2;

  float delta = th1 - th2;

  float den1 = L1 * (2*m1 + m2 - m2*cos(2*delta));
  float den2 = L2 * (2*m1 + m2 - m2*cos(2*delta));

  float dw1 =
    (-g*(2*m1 + m2)*sin(th1)
     - m2*g*sin(th1 - 2*th2)
     - 2*sin(delta)*m2*(w2*w2*L2 + w1*w1*L1*cos(delta)))
    / den1;

  float dw2 =
    (2*sin(delta)*
      (w1*w1*L1*(m1 + m2)
       + g*(m1 + m2)*cos(th1)
       + w2*w2*L2*m2*cos(delta)))
    / den2;

  return new float[] { dth1, dw1, dth2, dw2 };
}

void stepRK4(float h) {
  if (!isDouble) {
    float[] k1 = derivsSimple(th1, w1);
    float[] k2 = derivsSimple(th1 + 0.5*h*k1[0], w1 + 0.5*h*k1[1]);
    float[] k3 = derivsSimple(th1 + 0.5*h*k2[0], w1 + 0.5*h*k2[1]);
    float[] k4 = derivsSimple(th1 + h*k3[0],      w1 + h*k3[1]);

    th1 += (h/6.0) * (k1[0] + 2*k2[0] + 2*k3[0] + k4[0]);
    w1  += (h/6.0) * (k1[1] + 2*k2[1] + 2*k3[1] + k4[1]);
  } else {
    float[] k1 = derivsDouble(th1, w1, th2, w2);
    float[] k2 = derivsDouble(th1 + 0.5*h*k1[0], w1 + 0.5*h*k1[1],
                              th2 + 0.5*h*k1[2], w2 + 0.5*h*k1[3]);
    float[] k3 = derivsDouble(th1 + 0.5*h*k2[0], w1 + 0.5*h*k2[1],
                              th2 + 0.5*h*k2[2], w2 + 0.5*h*k2[3]);
    float[] k4 = derivsDouble(th1 + h*k3[0], w1 + h*k3[1],
                              th2 + h*k3[2], w2 + h*k3[3]);

    th1 += (h/6.0) * (k1[0] + 2*k2[0] + 2*k3[0] + k4[0]);
    w1  += (h/6.0) * (k1[1] + 2*k2[1] + 2*k3[1] + k4[1]);

    th2 += (h/6.0) * (k1[2] + 2*k2[2] + 2*k3[2] + k4[2]);
    w2  += (h/6.0) * (k1[3] + 2*k2[3] + 2*k3[3] + k4[3]);
  }
}

// ======================================================
// COMMUTACIÓ DE MODE
// ======================================================
void switchMode(boolean toDouble) {
  isDouble = toDouble;
  updateSliderEnables();

  // estat inicial per cada mode
  if (isDouble) {
    th1 = radians(120);
    th2 = radians(-10);
    w1 = 0; w2 = 0;
    drawScale = 200;
  } else {
    th1 = radians(60);
    w1  = 0;
    th2 = 0; w2 = 0;
    drawScale = 300;
  }

  computeLayout();
  computeDrawScale();
  layoutSliders();
  layoutSpectrumButton();
  layoutGraphButtons();

  // bases
  baseM1 = m1; baseM2 = m2;
  baseL1 = L1; baseL2 = L2;
  baseG  = g;
  baseTh1 = th1; baseTh2 = th2;
  baseW1  = w1;  baseW2  = w2;

  E0 = energyTotal();
  updateEnergyMonitor();

  // neteja visuals
  clearTrajectoryLayer();
  for (int i = 0; i < trailLength; i++) trail[i] = null;
  trailIndex = 0;

  for (int i = 0; i < xyHistoryN; i++) { tXYBuf[i]=0; xBuf[i]=0; yBuf[i]=0; }
  xyIndex = 0; xyFilled = false;
  xySamplesTotal = 0;
  lastSpectrumSamples = 0;

  for (int i = 0; i < angHistoryN; i++) { tAngBuf[i]=0; thBuf[i]=0; wBuf[i]=0; }
  angIndex = 0; angFilled = false;

  time = 0;
  stepCounter = 0;
}

// ======================================================
// ENTRADES
// ======================================================
void keyPressed() {
  if (key == ' ') paused = !paused;

  if (key == 'c' || key == 'C') {
    for (int i = 0; i < trailLength; i++) trail[i] = null;
    trailIndex = 0;
  }

  if (key == 'x' || key == 'X') {
    clearTrajectoryLayer();
  }

  if (key == '+') physicsStepsPerFrame++;
  if (key == '-' && physicsStepsPerFrame > 1) physicsStepsPerFrame--;
}

void saveScreenshotPNG() {
  saveFrame("captures/caos_determinista-######.png");
}

void mousePressed() {
  modeToggle.mousePressed();
  if (knobScale != null) knobScale.mousePressed();
  if (knobSpeed != null) knobSpeed.mousePressed();

  // sliders
  sM1.mousePressed();
  sM2.mousePressed();
  sL1.mousePressed();
  sL2.mousePressed();
  sG.mousePressed();
  sTh1.mousePressed();
  sTh2.mousePressed();

  // botons
  if (btnScreenshot != null && btnScreenshot.hit(mouseX, mouseY)) saveScreenshotPNG();
  else if (btnTrajAuto.hit(mouseX, mouseY)) autoscaleTrajectory();
  else if (btnTrajCap.hit(mouseX, mouseY)) toggleTrajRecord();
  else if (btnXYCap.hit(mouseX, mouseY)) toggleXYRecord();
  else if (btnAngCap.hit(mouseX, mouseY)) toggleAngRecord();
  else if (btnResetAll.hit(mouseX, mouseY)) resetAllToInitial();
  else if (btnAngles.hit(mouseX, mouseY)) resetPerturbedAnglesSameEnergy();
  else if (btnParams.hit(mouseX, mouseY)) resetPerturbedParamsSameEnergy();
  else if (btnSpectrum.hit(mouseX, mouseY)) {
    showSpectrum = !showSpectrum;
    updateSpectrumButtonLabel();
    if (showSpectrum) {
      computeSpectrumFromFullHistory();
    } else {
      spectrumFrozen = false;
      specN = 0;
    }
  } else if (showSpectrum && btnSpecRecalc.hit(mouseX, mouseY)) {
    computeSpectrumFromFullHistory();
  } else if (btnSpecScale.hit(mouseX, mouseY)) {
    spectrumLogY = !spectrumLogY;
    updateSpectrumButtonLabel();
  } else if (btnSpecAlgo.hit(mouseX, mouseY)) {
    spectrumUseDFT = !spectrumUseDFT;
    updateSpectrumButtonLabel();
  }
}

void mouseDragged() {
  if (knobScale != null) knobScale.mouseDragged();
  if (knobSpeed != null) knobSpeed.mouseDragged();
  sM1.mouseDragged();
  sM2.mouseDragged();
  sL1.mouseDragged();
  sL2.mouseDragged();
  sG.mouseDragged();
  sTh1.mouseDragged();
  sTh2.mouseDragged();
}

void mouseReleased() {
  if (knobScale != null) knobScale.mouseReleased();
  if (knobSpeed != null) knobSpeed.mouseReleased();
  sM1.mouseReleased();
  sM2.mouseReleased();
  sL1.mouseReleased();
  sL2.mouseReleased();
  sG.mouseReleased();
  sTh1.mouseReleased();
  sTh2.mouseReleased();

  // Quan acabes d'ajustar, fem que els resets prenguin això com a "base"
  baseM1 = m1; baseM2 = m2;
  baseL1 = L1; baseL2 = L2;
  baseG  = g;
}

void exit() {
  stopTrajRecord();
  stopXYRecord();
  stopAngRecord();
  super.exit();
}

String timeStamp() {
  return nf(year(), 4) + nf(month(), 2) + nf(day(), 2) + "_" + nf(hour(), 2) + nf(minute(), 2) + nf(second(), 2);
}

void startTrajRecord() {
  if (recTraj) return;
  stopXYRecord();
  stopAngRecord();
  trajWriter = createWriter("traj_total_" + timeStamp() + ".txt");
  trajWriter.println("# t\tx\ty   (x,y físics)");
  recTraj = true;
}

void toggleTrajRecord() {
  if (recTraj) stopTrajRecord();
  else startTrajRecord();
}

void stopTrajRecord() {
  if (trajWriter != null) { trajWriter.flush(); trajWriter.close(); }
  trajWriter = null;
  recTraj = false;
}

void startXYRecord() {
  if (recXY) return;
  stopTrajRecord();
  stopAngRecord();
  xyWriter = createWriter("xy_t_" + timeStamp() + ".txt");
  xyWriter.println("# t\tx\ty   (x,y físics)");
  recXY = true;
}

void toggleXYRecord() {
  if (showSpectrum) {
    exportXYSpectrum();
    return;
  }
  if (recXY) stopXYRecord();
  else startXYRecord();
}

void stopXYRecord() {
  if (xyWriter != null) { xyWriter.flush(); xyWriter.close(); }
  xyWriter = null;
  recXY = false;
}

void startAngRecord() {
  if (recAng) return;
  stopTrajRecord();
  stopXYRecord();
  angWriter = createWriter("theta_w_" + timeStamp() + ".txt");
  angWriter.println("# t\ttheta\tomega   (rad, rad/s)");
  recAng = true;
}

void toggleAngRecord() {
  if (recAng) stopAngRecord();
  else startAngRecord();
}

void stopAngRecord() {
  if (angWriter != null) { angWriter.flush(); angWriter.close(); }
  angWriter = null;
  recAng = false;
}

void ensureSpectrumCapacity(int n) {
  if (n > fftX.length) {
    fftX = new float[n];
    fftY = new float[n];
    fftT = new float[n];
    fftImX = new float[n];
    fftImY = new float[n];
  }
  int specLen = max(2, n / 2);
  if (specLen > specX.length) {
    specX = new float[specLen];
    specY = new float[specLen];
    specF = new float[specLen];
  }
}

void computeSpectrumFromFullHistory() {
  int nAll = tAll.size();
  if (nAll < 8) { spectrumFrozen = false; specN = 0; return; }

  float dtSum = 0;
  for (int i = 0; i < nAll - 1; i++) dtSum += (tAll.get(i+1) - tAll.get(i));
  float dtAvg = dtSum / max(1, nAll - 1);
  if (dtAvg <= 1e-6) dtAvg = dt;
  float fNyq = 0.5 / dtAvg;
  lastFNyq = fNyq;

  int nFFT = 1;
  while (nFFT < nAll) nFFT <<= 1;
  ensureSpectrumCapacity(nFFT);

  for (int i = 0; i < nFFT; i++) {
    if (i < nAll) {
      fftX[i] = xAll.get(i);
      fftY[i] = yAll.get(i);
      fftT[i] = tAll.get(i);
    } else {
      fftX[i] = 0;
      fftY[i] = 0;
      fftT[i] = fftT[nAll - 1] + (i - nAll + 1) * dtAvg;
    }
  }

  float fMinDisplay = max(0.0, spectrumFMin);
  float fMaxDisplay = max(fMinDisplay + 1e-6, fNyq);
  float fRangeDisplay = fMaxDisplay - fMinDisplay;

  int kMaxFFT = nFFT / 2;
  int kMaxPlot = max(2, min(spectrumFreqPoints, specX.length));
  if (!spectrumUseDFT) kMaxPlot = min(kMaxPlot, kMaxFFT);

  if (spectrumUseDFT) {
    for (int k = 0; k < kMaxPlot; k++) {
      float ff = fMinDisplay + fRangeDisplay * (k / (float)(kMaxPlot - 1));
      specF[k] = ff;
      if (ff > fNyq) {
        specX[k] = 0;
        specY[k] = 0;
        continue;
      }
      float reX = 0, imX = 0, reY = 0, imY = 0;
      for (int j = 0; j < nAll; j++) {
        float w = 0.5 - 0.5 * cos(TWO_PI * j / (nAll - 1));
        float ang = TWO_PI * ff * j * dtAvg;
        float ca = cos(ang);
        float sa = sin(ang);
        float x = xAll.get(j) * w;
        float y = yAll.get(j) * w;
        reX += x * ca;
        imX -= x * sa;
        reY += y * ca;
        imY -= y * sa;
      }
      specX[k] = sqrt(reX*reX + imX*imX) / nAll;
      specY[k] = sqrt(reY*reY + imY*imY) / nAll;
    }
  } else {
    for (int i = 0; i < nFFT; i++) {
      float w = (i < nAll) ? (0.5 - 0.5 * cos(TWO_PI * i / (nAll - 1))) : 0;
      fftX[i] *= w;
      fftY[i] *= w;
      fftImX[i] = 0;
      fftImY[i] = 0;
    }
    fftRadix2(fftX, fftImX, nFFT);
    fftRadix2(fftY, fftImY, nFFT);
    for (int k = 0; k < kMaxPlot; k++) {
      float ff = fMinDisplay + fRangeDisplay * (k / (float)(kMaxPlot - 1));
      specF[k] = ff;
      if (ff > fNyq) {
        specX[k] = 0;
        specY[k] = 0;
        continue;
      }
      float bin = ff * (kMaxFFT / fNyq);
      int k0 = constrain((int)floor(bin), 0, kMaxFFT);
      int k1 = min(k0 + 1, kMaxFFT);
      float t = bin - k0;
      float reX0 = fftX[k0];
      float imX0 = fftImX[k0];
      float reY0 = fftY[k0];
      float imY0 = fftImY[k0];
      float magX0 = sqrt(reX0*reX0 + imX0*imX0) / nFFT;
      float magY0 = sqrt(reY0*reY0 + imY0*imY0) / nFFT;
      if (k1 == k0) {
        specX[k] = magX0;
        specY[k] = magY0;
      } else {
        float reX1 = fftX[k1];
        float imX1 = fftImX[k1];
        float reY1 = fftY[k1];
        float imY1 = fftImY[k1];
        float magX1 = sqrt(reX1*reX1 + imX1*imX1) / nFFT;
        float magY1 = sqrt(reY1*reY1 + imY1*imY1) / nFFT;
        specX[k] = lerp(magX0, magX1, t);
        specY[k] = lerp(magY0, magY1, t);
      }
    }
  }

  specN = kMaxPlot;
  spectrumFrozen = true;
}

void exportXYSpectrum() {
  if (spectrumFrozen && specN > 0) {
    PrintWriter w = createWriter("spectrum_xy_" + timeStamp() + ".txt");
    w.println("# f\t|X|\t|Y|");
    for (int k = 0; k < specN; k++) {
      w.println(specF[k] + "\t" + specX[k] + "\t" + specY[k]);
    }
    w.flush();
    w.close();
    return;
  }

  int nAvail = xyFilled ? xyHistoryN : xyIndex;
  int n = min(nAvail, spectrumHistoryN);
  if (n < 8) return;

  for (int i = 0; i < n; i++) {
    int idx;
    if (xyFilled) idx = (xyIndex + (nAvail - n) + i) % xyHistoryN;
    else idx = i;
    fftX[i] = xBuf[idx];
    fftY[i] = yBuf[idx];
    fftT[i] = tXYBuf[idx];
  }

  float dtSum = 0;
  for (int i = 0; i < n-1; i++) dtSum += (fftT[i+1] - fftT[i]);
  float dtAvg = dtSum / max(1, n-1);
  if (dtAvg <= 1e-6) dtAvg = dt;

  float fNyq = 0.5 / dtAvg;
  lastFNyq = fNyq;
  float fMinDisplay = max(0.0, spectrumFMin);
  float fMaxDisplay = max(fMinDisplay + 1e-6, fNyq);
  float fRangeDisplay = fMaxDisplay - fMinDisplay;

  int nFFT = 1;
  while (nFFT * 2 <= n) nFFT *= 2;
  int kMaxFFT = nFFT / 2;
  int kMaxPlot = max(2, min(spectrumFreqPoints, specX.length));
  if (!spectrumUseDFT) kMaxPlot = min(kMaxPlot, kMaxFFT);

  if (spectrumUseDFT) {
    for (int k = 0; k < kMaxPlot; k++) {
      float ff = fMinDisplay + fRangeDisplay * (k / (float)(kMaxPlot - 1));
      if (ff > fNyq) {
        specX[k] = 0;
        specY[k] = 0;
        continue;
      }
      float reX = 0, imX = 0, reY = 0, imY = 0;
      for (int j = 0; j < n; j++) {
        float w = 0.5 - 0.5 * cos(TWO_PI * j / (n - 1));
        float ang = TWO_PI * ff * j * dtAvg;
        float ca = cos(ang);
        float sa = sin(ang);
        float x = fftX[j] * w;
        float y = fftY[j] * w;
        reX += x * ca;
        imX -= x * sa;
        reY += y * ca;
        imY -= y * sa;
      }
      specX[k] = sqrt(reX*reX + imX*imX) / n;
      specY[k] = sqrt(reY*reY + imY*imY) / n;
    }
  } else {
    int start = max(0, n - nFFT);
    for (int i = 0; i < nFFT; i++) {
      float w = 0.5 - 0.5 * cos(TWO_PI * i / (nFFT - 1));
      fftX[i] = fftX[start + i] * w;
      fftY[i] = fftY[start + i] * w;
      fftImX[i] = 0;
      fftImY[i] = 0;
    }
    fftRadix2(fftX, fftImX, nFFT);
    fftRadix2(fftY, fftImY, nFFT);
    for (int k = 0; k < kMaxPlot; k++) {
      float ff = fMinDisplay + fRangeDisplay * (k / (float)(kMaxPlot - 1));
      if (ff > fNyq) {
        specX[k] = 0;
        specY[k] = 0;
        continue;
      }
      int idx = int(map(ff, 0, fNyq, 0, kMaxFFT-1));
      specX[k] = sqrt(fftX[idx]*fftX[idx] + fftImX[idx]*fftImX[idx]) / nFFT;
      specY[k] = sqrt(fftY[idx]*fftY[idx] + fftImY[idx]*fftImY[idx]) / nFFT;
    }
  }

  PrintWriter w = createWriter("spectrum_xy_" + timeStamp() + ".txt");
  w.println("# f\t|X|\t|Y|");
  for (int k = 0; k < kMaxPlot; k++) {
    float ff = fMinDisplay + fRangeDisplay * (k / (float)(kMaxPlot - 1));
    w.println(ff + "\t" + specX[k] + "\t" + specY[k]);
  }
  w.flush();
  w.close();
}
