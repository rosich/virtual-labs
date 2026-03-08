import java.util.Locale;

// ------------------------------------------------------------
// Layout + generació N(mu, sigma) + regressió lineal + histograma
// Primera iteració (GUI manual simple)
// ------------------------------------------------------------

ArrayList<Float> yData = new ArrayList<Float>();
ArrayList<Float> xData = new ArrayList<Float>();

// Paràmetres generació
float mu = 0.0;
float sigma = 1.0;
float mGen = 0.0;

// Estadístics (estimats a partir de dades)
float muHat = 0.0;
float sigmaHat = 1.0;

// Regressió y = a + b x
float regA = 0.0;   // intercept
float regB = 0.0;   // slope
float regT = Float.NaN;
float regP = Float.NaN;
float regSEm = 0.0;
float regSEb = 0.0;
float regMSE = Float.NaN;

// UI
IconButton genButton;
IconButton resetButton;
IconButton saveButton;
IconButton genResetButton;
IconButton screenshotButton;
int genResetCount = 0;
int pSigCount = 0;
ToggleButton t1, t10, t100, t1000;
ToggleButton histDirect, histDiff;
Slider muSlider, sigmaSlider, mSlider;
CheckBox nonEquiBox;
PFont baseFont;

// Layout rects
PRect panel;
PRect leftPlot;
PRect rightPlot;
PRect controlsArea;
float controlsPad = 16;
float axisTickLen = 6;

void setup() {
  size(1200, 720);
  surface.setTitle("Random");
  smooth(4);
  baseFont = createFont("SansSerif", 12, false);
  textFont(baseFont);

  // Panell principal
  panel = new PRect(20, 20, width-40, height-40);

  // Dins del panell, dos plots a dalt i controls a baix
  float pad = 20;
  float plotH = panel.h * 0.68;
  float plotW = (panel.w - pad*3) * 0.5;
  float topInset = 24;

  leftPlot  = new PRect(panel.x + pad,             panel.y + pad + topInset, plotW, plotH);
  rightPlot = new PRect(panel.x + pad*2 + plotW,   panel.y + pad + topInset, plotW, plotH);

  controlsArea = new PRect(panel.x + pad, panel.y + pad*2 + plotH + topInset, panel.w - pad*2, panel.h - plotH - pad*3 - topInset);

  // Botó generar (icona play)
  float row1Y = controlsArea.y + controlsPad;
  genButton = new IconButton(controlsArea.x + controlsPad, row1Y, 90, 42, "Genera", 0, color(190, 235, 180));
  resetButton = new IconButton(genButton.x + genButton.w + 12, row1Y, 78, 42, "Reset", 1);
  saveButton = new IconButton(resetButton.x + resetButton.w + 12, row1Y, 86, 42, "Guarda", 2);
  genResetButton = new IconButton(saveButton.x + saveButton.w + 12, row1Y, 120, 42, "Gen+Reset");

  // Toggles x1 x10 x100 x1000
  float tx = genResetButton.x + genResetButton.w + 16;
  float ty1 = genButton.y;
  float ty2 = ty1 + 28 + 8;
  float tw = 62;
  float th = 28;
  float tgap = 8;
  t1   = new ToggleButton(tx,              ty1,  tw, th, "x1");
  t10  = new ToggleButton(tx + tw + tgap,  ty1,  tw, th, "x10");
  t100 = new ToggleButton(tx,              ty2,  tw, th, "x100");
  t1000 = new ToggleButton(tx + tw + tgap, ty2,  tw, th, "x1000");
  t1.isOn = true;
  screenshotButton = new IconButton(tx + 132 + 16, row1Y, 132, 42, "Captura PNG", 2);

  // Checkbox no equiespaiat
  nonEquiBox = new CheckBox(controlsArea.x + controlsPad, genButton.y + genButton.h + 10, 14, "X no equiespaiat (0.5-4)");

  // Tabs histograma (directe vs diferències)
  histDirect = new ToggleButton(rightPlot.x + 10, rightPlot.y + 6, 120, 22, "I(0)");
  histDiff = new ToggleButton(rightPlot.x + 136, rightPlot.y + 6, 120, 22, "I(1)");
  histDiff.isOn = true;

  // Sliders a la dreta dels controls
  float sliderW = min(360, controlsArea.w * 0.40);
  float sx = controlsArea.x + controlsArea.w - sliderW - controlsPad;
  float sy = row1Y + 6;

  muSlider = new Slider(sx, sy, sliderW, 14, -5, 5, mu, "μ (mitjana)");
  sigmaSlider = new Slider(sx, sy + 46, sliderW, 14, 0.1, 5, sigma, "σ (sigma)");
  mSlider = new Slider(sx, sy + 92, sliderW, 14, -1, 1, mGen, "m (pendent)");

  recomputeStats();
}

void draw() {
  textFont(baseFont);
  background(245);

  // Panell
  // drawPanel(panel);

  // Controls
  drawControls();
  // Sincronitza paràmetres amb sliders
  mu = muSlider.value;
  sigma = sigmaSlider.value;
  mGen = mSlider.value;

  // Plots
  drawRegressionPlot(leftPlot);
  histDirect.draw();
  histDiff.draw();
  drawHistogramPlot(rightPlot);
}

void drawPanel(PRect r) {
  stroke(40);
  strokeWeight(2);
  noFill();
  rect(r.x, r.y, r.w, r.h, 10);
}

void drawControls() {
  // Zona controls (separador suau)
  stroke(200);
  strokeWeight(1);
  line(controlsArea.x, controlsArea.y, controlsArea.x + controlsArea.w, controlsArea.y);

  genButton.draw();
  resetButton.draw();
  saveButton.draw();
  genResetButton.draw();
  screenshotButton.draw();

  // Toggles
  t1.draw(); 
  t10.draw(); 
  t100.draw();
  t1000.draw();

  // Sliders
  muSlider.draw();
  sigmaSlider.draw();
  mSlider.draw();

  // Text d'estat
  fill(30);
  textAlign(LEFT, CENTER);
  textSize(12);

  float infoY1 = controlsArea.y + controlsArea.h - 48 + 25;
  float infoGap = 20;
  // Checkbox alineat amb el bloc d'informació
  nonEquiBox.x = controlsArea.x + controlsPad;
  nonEquiBox.y = (infoY1 - infoGap) - nonEquiBox.s * 0.5;
  nonEquiBox.draw();
  String multStr = "Punts per clic: " + getMultiplier();
  text(multStr, controlsArea.x + controlsPad, infoY1);

  String nStr = "N = " + yData.size();
  text(nStr, controlsArea.x + controlsPad, infoY1 + infoGap);

  String sigStr = "p<0.05: " + pSigCount + " / " + genResetCount;
  text(sigStr, genResetButton.x, genResetButton.y + genResetButton.h + 16);
}

void drawRegressionPlot(PRect r) {
  // Marc plot
  drawPlotFrame(r, "Regressió lineal");

  // Zona interna (marges)
  float m = 40;
  float x0 = r.x + m;
  float y0 = r.y + r.h - m;
  float w = r.w - 2*m;
  float h = r.h - 2*m;

  // Eixos
  stroke(120);
  strokeWeight(1);
  line(x0, y0, x0 + w, y0);      // x
  line(x0, y0 + axisTickLen, x0, y0 - h);      // y

  if (yData.size() < 2) {
    fill(120);
    textAlign(CENTER, CENTER);
    textSize(12);
    text("Genera punts per veure la regressió", r.x + r.w*0.5, r.y + r.h*0.5);
    return;
  }

  // Escales
  int N = yData.size();
  float xMin = nonEquiBox.isOn ? minX() : 0.5;
  float xMax = nonEquiBox.isOn ? maxX() : (N + 0.5);
  if (nonEquiBox.isOn) {
    float padX = (xMax - xMin) * 0.06;
    if (padX == 0) padX = 0.2;
    xMin -= padX;
    xMax += padX;
  }

  float yMin = minY();
  float yMax = maxY();
  // Inclou barres d'error (±1σ) en el rang
  float err = sigma;
  yMin -= err;
  yMax += err;
  float padY = (yMax - yMin) * 0.10;
  if (padY == 0) padY = 1;
  yMin -= padY;
  yMax += padY;

  drawAxisTicks(x0, y0, w, h, xMin, xMax, yMin, yMax, 6, 6, !nonEquiBox.isOn, false);
  drawAxisLabels(x0, y0, w, h, "X", "Y");

  // Dibuixa punts + barres d'incertesa (±1σ)
  err = sigma;
  float cap = 6;
  stroke(20, 80);
  strokeWeight(1.5);
  for (int i = 0; i < N; i++) {
    float xi = xData.get(i);
    float yi = yData.get(i);

    float px = map(xi, xMin, xMax, x0, x0 + w);
    float py = map(yi, yMin, yMax, y0, y0 - h);
    float pyTop = map(yi + err, yMin, yMax, y0, y0 - h);
    float pyBot = map(yi - err, yMin, yMax, y0, y0 - h);

    line(px, pyTop, px, pyBot);
    line(px - cap, pyTop, px + cap, pyTop);
    line(px - cap, pyBot, px + cap, pyBot);
  }

  stroke(20, 120);
  strokeWeight(4);
  for (int i = 0; i < N; i++) {
    float xi = xData.get(i);
    float yi = yData.get(i);
    float px = map(xi, xMin, xMax, x0, x0 + w);
    float py = map(yi, yMin, yMax, y0, y0 - h);
    point(px, py);
  }

  // Regressió: línia entre extrems
  float yAtMin = regA + regB * xMin;
  float yAtMax = regA + regB * xMax;

  float p1x = map(xMin, xMin, xMax, x0, x0 + w);
  float p1y = map(yAtMin, yMin, yMax, y0, y0 - h);

  float p2x = map(xMax, xMin, xMax, x0, x0 + w);
  float p2y = map(yAtMax, yMin, yMax, y0, y0 - h);

  stroke(30, 110, 220);
  strokeWeight(2);
  line(p1x, p1y, p2x, p2y);


  // Banda d'incertesa (±sqrt(MSE)) en blau clar
  if (!Float.isNaN(regMSE)) {
    float band = sqrt(regMSE);
    int steps = 120;
    noStroke();
    fill(120, 180, 255, 60);
    beginShape();
    for (int i = 0; i <= steps; i++) {
      float xv = map(i, 0, steps, xMin, xMax);
      float yv = regA + regB * xv + band;
      float px = map(xv, xMin, xMax, x0, x0 + w);
      float py = map(yv, yMin, yMax, y0, y0 - h);
      vertex(px, py);
    }
    for (int i = steps; i >= 0; i--) {
      float xv = map(i, 0, steps, xMin, xMax);
      float yv = regA + regB * xv - band;
      float px = map(xv, xMin, xMax, x0, x0 + w);
      float py = map(yv, yMin, yMax, y0, y0 - h);
      vertex(px, py);
    }
    endShape(CLOSE);
  }

  // Paràmetres ajustats a la dreta del plot
  float infoX = r.x + r.w - 12;
  fill(40);
  textAlign(RIGHT, TOP);
  textSize(12);
  text("m = " + formatMaybeSci(regB) + " \u00B1 " + formatMaybeSci(regSEm), infoX, r.y + 12);
  text("b = " + formatMaybeSci(regA) + " \u00B1 " + formatMaybeSci(regSEb), infoX, r.y + 28);
  text("t(m) = " + formatMaybeSci(regT), infoX, r.y + 44);
  if (!Float.isNaN(regP) && regP < 0.05) fill(200, 40, 40);
  text("p(m) = " + formatMaybeSci(regP), infoX, r.y + 60);
  fill(40);
}

void drawHistogramPlot(PRect r) {
  // Reubica tabs dins del quadre, cantonada superior dreta
  float tabGap = 6;
  float hx = r.x + 10;
  float hy = r.y + 6;
  histDirect.x = hx;
  histDirect.y = hy;
  histDiff.x = hx + histDirect.w + tabGap;
  histDiff.y = hy;

  boolean useDiffs = histDiff.isOn;
  String title = "Histograma";
  drawPlotFrame(r, title);

  float m = 40;
  float x0 = r.x + m;
  float y0 = r.y + r.h - m;
  float w = r.w - 2*m;
  float h = r.h - 2*m;

  // Eixos
  stroke(120);
  strokeWeight(1);
  line(x0, y0, x0 + w, y0);
  line(x0, y0 + axisTickLen, x0, y0 - h);

  if ((useDiffs && yData.size() < 2) || (!useDiffs && yData.size() < 1)) {
    fill(120);
    textAlign(CENTER, CENTER);
    textSize(12);
    text("Genera punts per veure l'histograma", r.x + r.w*0.5, r.y + r.h*0.5);
    return;
  }

  // Dades per histograma
  float[] data;
  float muHist;
  float sigmaHist;
  if (useDiffs) {
    int nDiff = yData.size() - 1;
    data = new float[nDiff];
    for (int i = 1; i < yData.size(); i++) {
      data[i - 1] = yData.get(i) - yData.get(i - 1);
    }

    float muDiff = 0;
    for (float v : data) muDiff += v;
    muDiff /= nDiff;
    float ssDiff = 0;
    for (float v : data) ssDiff += (v - muDiff) * (v - muDiff);
    float sigmaDiff = (nDiff > 1) ? sqrt(ssDiff / (nDiff - 1)) : 1;
    if (sigmaDiff < 1e-6) sigmaDiff = 1e-6;
    muHist = muDiff;
    sigmaHist = sigmaDiff;
  } else {
    int n = yData.size();
    data = new float[n];
    for (int i = 0; i < n; i++) data[i] = yData.get(i);
    muHist = muHat;
    sigmaHist = sigmaHat;
  }

  // Bins
  int bins = 18;
  float yMin = data[0];
  float yMax = data[0];
  for (float v : data) {
    yMin = min(yMin, v);
    yMax = max(yMax, v);
  }
  float padY = (yMax - yMin) * 0.15;
  if (padY == 0) padY = 1;
  yMin -= padY;
  yMax += padY;

  float binW = (yMax - yMin) / bins;
  int[] counts = new int[bins];

  for (float v : data) {
    int b = int((v - yMin) / binW);
    b = constrain(b, 0, bins-1);
    counts[b]++;
  }

  int maxC = 1;
  for (int c : counts) maxC = max(maxC, c);

  drawAxisTicks(x0, y0, w, h, yMin, yMax, 0, maxC, 6, 6, false, true);
  drawAxisLabels(x0, y0, w, h, "X", "Y");

  // Barres
  noStroke();
  fill(60, 90);
  for (int i = 0; i < bins; i++) {
    float bx0 = map(i, 0, bins, x0, x0 + w);
    float bx1 = map(i+1, 0, bins, x0, x0 + w);
    float barH = map(counts[i], 0, maxC, 0, h);
    rect(bx0 + 1, y0 - barH, (bx1 - bx0) - 2, barH);
  }

  // Ajust normal
  // Converteix pdf a "counts" esperats: pdf * N * binW
  stroke(150, 90, 200);
  strokeWeight(2);
  noFill();

  beginShape();
  int steps = 220;
  float N = data.length;
  for (int i = 0; i <= steps; i++) {
    float xv = map(i, 0, steps, yMin, yMax);
    float pdf = normalPDF(xv, muHist, sigmaHist);
    float expected = pdf * N * binW; // altura en unitats "comptes"
    float px = map(xv, yMin, yMax, x0, x0 + w);
    float py = map(expected, 0, maxC, y0, y0 - h);
    vertex(px, py);
  }
  endShape();

  // Etiquetes muHat / sigmaHat a la dreta del plot
  float infoX = r.x + r.w - 12;
  fill(40);
  noStroke();
  textAlign(RIGHT, TOP);
  textSize(12);
  String muLab = useDiffs ? "μ̂Δ = " : "μ̂ = ";
  String sigLab = useDiffs ? "σ̂Δ = " : "σ̂ = ";
  text(muLab + formatMaybeSci(muHist), infoX, r.y + 12);
  text(sigLab + formatMaybeSci(sigmaHist), infoX, r.y + 28);

  // També mostra μ,σ de generació (sliders)
  text("μ (gen) = " + formatMaybeSci(mu), infoX, r.y + 50);
  text("σ (gen) = " + formatMaybeSci(sigma), infoX, r.y + 66);
}

void drawPlotFrame(PRect r, String title) {
  stroke(90);
  strokeWeight(1);
  noFill();
  rect(r.x, r.y, r.w, r.h, 8);

  fill(30);
  noStroke();
  textAlign(LEFT, BOTTOM);
  textFont(baseFont);
  textSize(18);
  text(title, r.x + 10, r.y - 6);
}

void drawAxisTicks(float x0, float y0, float w, float h,
                   float xMin, float xMax, float yMin, float yMax,
                   int xTicks, int yTicks, boolean xInt, boolean yInt) {
  stroke(120);
  strokeWeight(1);
  float tick = axisTickLen;

  float xStep = niceStep(xMax - xMin, xTicks);
  if (xInt) xStep = max(1, round(xStep));
  float xStart = ceil(xMin / xStep) * xStep;
  float yStep = niceStep(yMax - yMin, yTicks);
  if (yInt) yStep = max(1, round(yStep));
  float yStart = ceil(yMin / yStep) * yStep;

  // X ticks + labels
  String prevXLabel = "";
  for (float xv = xStart; xv <= xMax + 0.5 * xStep; xv += xStep) {
    if (xv < xMin - 1e-6 || xv > xMax + 1e-6) continue;
    if (xInt) {
      int xi = round(xv);
      if (xi < xMin || xi > xMax) continue;
      xv = xi;
    }
    float tx = map(xv, xMin, xMax, x0, x0 + w);
    line(tx, y0, tx, y0 + tick);
    String label = formatTickLabel(xv, xInt);
    if (label.equals(prevXLabel)) continue;
    prevXLabel = label;
    fill(40);
    noStroke();
    textAlign(CENTER, TOP);
    textSize(11);
    text(label, tx, y0 + tick + 2);
    stroke(120);
  }

  // Y ticks + labels
  String prevYLabel = "";
  for (float yv = yStart; yv <= yMax + 0.5 * yStep; yv += yStep) {
    if (yv < yMin - 1e-6 || yv > yMax + 1e-6) continue;
    if (yInt) {
      int yi = round(yv);
      if (yi < yMin || yi > yMax) continue;
      yv = yi;
    }
    float ty = map(yv, yMin, yMax, y0, y0 - h);
    line(x0 - tick, ty, x0, ty);
    String label = formatTickLabel(yv, yInt);
    if (label.equals(prevYLabel)) continue;
    prevYLabel = label;
    fill(40);
    noStroke();
    textAlign(RIGHT, CENTER);
    textSize(11);
    text(label, x0 - tick - 4, ty);
    stroke(120);
  }
}

void drawAxisLabels(float x0, float y0, float w, float h, String xLabel, String yLabel) {
  fill(40);
  noStroke();
  textSize(12);
  textAlign(CENTER, TOP);
  text(xLabel, x0 + w * 0.5, y0 + 18);
  textAlign(RIGHT, CENTER);
  text(yLabel, x0 - 24, y0 - h * 0.5);
}

float niceStep(float range, int ticks) {
  if (range <= 0) return 1;
  float raw = range / ticks;
  float exp = floor(log(raw) / log(10));
  float base = pow(10, exp);
  float frac = raw / base;
  float nice;
  if (frac <= 1) nice = 1;
  else if (frac <= 2) nice = 2;
  else if (frac <= 5) nice = 5;
  else nice = 10;
  return nice * base;
}

int decimalsForStep(float step) {
  if (step >= 1) return 0;
  if (step >= 0.1) return 1;
  if (step >= 0.01) return 2;
  return 3;
}

// ------------------- Interacció -------------------

void mousePressed() {
  // Botó genera
  if (genButton.hit(mouseX, mouseY)) {
    generatePoints(getMultiplier());
    return;
  }
  if (resetButton.hit(mouseX, mouseY)) {
    yData.clear();
    xData.clear();
    recomputeStats();
    genResetCount = 0;
    pSigCount = 0;
    return;
  }
  if (saveButton.hit(mouseX, mouseY)) {
    selectOutput("Desa les dades...", "saveDataFile");
    return;
  }
  if (screenshotButton.hit(mouseX, mouseY)) {
    saveScreenshotPNG();
    return;
  }
  if (genResetButton.hit(mouseX, mouseY)) {
    int k = getMultiplier();
    if (yData.size() > 0) {
      yData.clear();
      xData.clear();
      recomputeStats();
    }
    generatePoints(k);
    genResetCount++;
    if (!Float.isNaN(regP) && regP < 0.05) pSigCount++;
    return;
  }

  // Toggles (com a grup exclusiu)
  if (t1.hit(mouseX, mouseY))  setToggle(t1);
  if (t10.hit(mouseX, mouseY)) setToggle(t10);
  if (t100.hit(mouseX, mouseY)) setToggle(t100);
  if (t1000.hit(mouseX, mouseY)) setToggle(t1000);
  if (histDirect.hit(mouseX, mouseY)) setHistToggle(histDirect);
  if (histDiff.hit(mouseX, mouseY)) setHistToggle(histDiff);

  // Sliders
  if (yData.size() == 0) {
    muSlider.mousePressed(mouseX, mouseY);
    sigmaSlider.mousePressed(mouseX, mouseY);
    mSlider.mousePressed(mouseX, mouseY);
    nonEquiBox.mousePressed(mouseX, mouseY);
  }
}

void mouseDragged() {
  if (yData.size() == 0) {
    muSlider.mouseDragged(mouseX, mouseY);
    sigmaSlider.mouseDragged(mouseX, mouseY);
    mSlider.mouseDragged(mouseX, mouseY);
  }

  // Actualitza paràmetres de generació des dels sliders
  mu = muSlider.value;
  sigma = sigmaSlider.value;
  mGen = mSlider.value;
}

void mouseReleased() {
  if (yData.size() == 0) {
    muSlider.mouseReleased();
    sigmaSlider.mouseReleased();
    mSlider.mouseReleased();
  }
}

// ------------------- Lògica -------------------

int getMultiplier() {
  if (t1000.isOn) return 1000;
  if (t100.isOn) return 100;
  if (t10.isOn) return 10;
  return 1;
}

void setToggle(ToggleButton t) {
  t1.isOn = false;
  t10.isOn = false;
  t100.isOn = false;
  t1000.isOn = false;
  t.isOn = true;
}

void setHistToggle(ToggleButton t) {
  histDirect.isOn = false;
  histDiff.isOn = false;
  t.isOn = true;
}

void generatePoints(int k) {
  for (int i = 0; i < k; i++) {
    float x;
    if (nonEquiBox.isOn) {
      float prev = (xData.size() == 0) ? 0 : xData.get(xData.size() - 1);
      x = prev + random(0.5, 4.0);
    } else {
      x = yData.size() + 1;
    }
    float y = mGen * x + (float)randomGaussian() * sigma + mu;
    yData.add(y);
    xData.add(x);
  }
  recomputeStats();
}

void saveDataFile(File selection) {
  if (selection == null) return;
  PrintWriter out = createWriter(selection.getAbsolutePath());
  out.println("# n=" + yData.size());
  out.println("# mu_hat=" + muHat + " sigma_hat=" + sigmaHat);
  out.println("# m=" + regB + " b=" + regA + " se_m=" + regSEm + " se_b=" + regSEb);
  out.println("# t_m=" + regT + " p_m=" + regP);
  out.println("# mu_gen=" + mu + " sigma_gen=" + sigma + " m_gen=" + mGen);
  out.println("# format: index\ty\tsigma");
  for (int i = 0; i < yData.size(); i++) {
    out.println((i + 1) + "\t" + yData.get(i) + "\t" + sigma);
  }
  out.flush();
  out.close();
}

void saveScreenshotPNG() {
  saveFrame("captures/sig_estadistica-######.png");
}

void recomputeStats() {
  int n = yData.size();
  if (n == 0) {
    muHat = 0;
    sigmaHat = 1;
    regA = 0;
    regB = 0;
    regT = Float.NaN;
    regP = Float.NaN;
    regSEm = 0;
    regSEb = 0;
    regMSE = Float.NaN;
    return;
  }

  // muHat
  float s = 0;
  for (float v : yData) s += v;
  muHat = s / n;

  // sigmaHat (desviació típica mostra)
  float ss = 0;
  for (float v : yData) ss += (v - muHat)*(v - muHat);
  if (n > 1) sigmaHat = sqrt(ss / (n - 1));
  else sigmaHat = 1;
  if (sigmaHat < 1e-6) sigmaHat = 1e-6;

  // Regressió y vs x
  if (n > 1) {
    double meanX = 0;
    for (int i = 0; i < n; i++) meanX += xData.get(i);
    meanX /= n;
    double Sxx = 0;
    double Sxy = 0;
    double Syy = 0;
    for (int i = 0; i < n; i++) {
      double x = xData.get(i);
      double y = yData.get(i);
      double dx = x - meanX;
      double dy = y - muHat;
      Sxx += dx * dx;
      Sxy += dx * dy;
      Syy += dy * dy;
    }
    regB = (Sxx == 0) ? 0 : (float)(Sxy / Sxx);
    regA = (float)(muHat - regB * meanX);
    // t i p-valor per a la pendent
    if (n > 2 && Sxx > 0) {
      double sse = 0;
      for (int i = 0; i < n; i++) {
        double x = xData.get(i);
        double y = yData.get(i);
        double yhat = regA + regB * x;
        double r = y - yhat;
        sse += r * r;
      }
      double mse = sse / (n - 2.0);
      regMSE = (float)mse;
      double seB = Math.sqrt(mse / Sxx);
      double seA = Math.sqrt(mse * (1.0 / n + (meanX * meanX) / Sxx));
      regSEm = (float)seB;
      regSEb = (float)seA;
      if (seB > 0) {
        regT = (float)(regB / seB);
        regP = (float)twoSidedP(regT, n - 2.0);
      } else {
        regT = Float.NaN;
        regP = Float.NaN;
      }
    } else {
      regT = Float.NaN;
      regP = Float.NaN;
      regSEm = 0;
      regSEb = 0;
      regMSE = Float.NaN;
    }
  } else {
    regA = yData.get(0);
    regB = 0;
    regT = Float.NaN;
    regP = Float.NaN;
    regSEm = 0;
    regSEb = 0;
    regMSE = Float.NaN;
  }
}

float minY() {
  float m = yData.get(0);
  for (float v : yData) m = min(m, v);
  return m;
}

float maxY() {
  float m = yData.get(0);
  for (float v : yData) m = max(m, v);
  return m;
}

float minX() {
  float m = xData.get(0);
  for (float v : xData) m = min(m, v);
  return m;
}

float maxX() {
  float m = xData.get(0);
  for (float v : xData) m = max(m, v);
  return m;
}

float normalPDF(float x, float m, float s) {
  float z = (x - m) / s;
  return (1.0 / (sqrt(TWO_PI) * s)) * exp(-0.5 * z * z);
}

// ------------------- Estadística (t i p-valor) -------------------

double twoSidedP(double t, double df) {
  double cdf = tCDF(t, df);
  double p = 2.0 * Math.min(cdf, 1.0 - cdf);
  return Math.max(0.0, Math.min(1.0, p));
}

double oneSidedPAbs(double t, double df) {
  double cdf = tCDF(Math.abs(t), df);
  double p = 1.0 - cdf;
  return Math.max(0.0, Math.min(1.0, p));
}

double tCDF(double t, double df) {
  if (df <= 0) return Double.NaN;
  double x = df / (df + t * t);
  double a = df / 2.0;
  double b = 0.5;
  double ib = betai(a, b, x);
  if (t >= 0) return 1.0 - 0.5 * ib;
  else return 0.5 * ib;
}

double betai(double a, double b, double x) {
  if (x < 0.0 || x > 1.0) return Double.NaN;
  if (x == 0.0 || x == 1.0) return x;
  double bt = Math.exp(logGamma(a + b) - logGamma(a) - logGamma(b)
                  + a * Math.log(x) + b * Math.log(1.0 - x));
  if (x < (a + 1.0) / (a + b + 2.0)) {
    return bt * betacf(a, b, x) / a;
  } else {
    return 1.0 - bt * betacf(b, a, 1.0 - x) / b;
  }
}

double betacf(double a, double b, double x) {
  int maxIter = 200;
  double eps = 3.0e-7;
  double am = 1.0;
  double bm = 1.0;
  double az = 1.0;
  double qab = a + b;
  double qap = a + 1.0;
  double qam = a - 1.0;
  double bz = 1.0 - qab * x / qap;

  for (int m = 1; m <= maxIter; m++) {
    int m2 = 2 * m;
    double d = m * (b - m) * x / ((qam + m2) * (a + m2));
    double ap = az + d * am;
    double bp = bz + d * bm;
    d = -(a + m) * (qab + m) * x / ((a + m2) * (qap + m2));
    double app = ap + d * az;
    double bpp = bp + d * bz;
    double aold = az;
    am = ap / bpp;
    bm = bp / bpp;
    az = app / bpp;
    bz = 1.0;
    if (Math.abs(az - aold) < eps * Math.abs(az)) {
      return az;
    }
  }
  return az;
}

double logGamma(double xx) {
  double[] cof = {76.18009172947146, -86.50532032941677,
                  24.01409824083091, -1.231739572450155,
                  0.1208650973866179e-2, -0.5395239384953e-5};
  double x = xx - 1.0;
  double tmp = x + 5.5;
  tmp -= (x + 0.5) * Math.log(tmp);
  double ser = 1.000000000190015;
  for (int j = 0; j < 6; j++) {
    x += 1.0;
    ser += cof[j] / x;
  }
  return -tmp + Math.log(2.5066282746310005 * ser);
}

String formatMaybeSci(double v) {
  if (Double.isNaN(v) || Double.isInfinite(v)) return "NA";
  float fv = (float)v;
  String fixed = nf(fv, 0, 3);
  if (fixed.equals("0.000") || fixed.equals("-0.000") || fixed.equals("0,000") || fixed.equals("-0,000")) {
    return String.format(Locale.US, "%.2e", v);
  }
  return fixed;
}

String sci(double v, int digits) {
  if (Double.isNaN(v) || Double.isInfinite(v)) return "NA";
  return String.format(Locale.US, "%." + digits + "e", v);
}

String zeroLabelToSci(String label, double v) {
  if (v == 0) return "0";
  String s = label;
  if (s.startsWith("-")) s = s.substring(1);
  s = s.replace(".", "");
  boolean allZero = s.length() > 0;
  for (int i = 0; i < s.length(); i++) {
    if (s.charAt(i) != '0') { allZero = false; break; }
  }
  if (allZero) return sci(v, 2);
  return label;
}

String formatTickLabel(double v, boolean isInt) {
  if (isInt) return str(round((float)v));
  if (v == 0) return "0";
  return String.format(Locale.US, "%.1g", v);
}

// ------------------- Classes UI simples -------------------

class PRect {
  float x, y, w, h;
  PRect(float x, float y, float w, float h) { this.x=x; this.y=y; this.w=w; this.h=h; }
  boolean contains(float px, float py) { return px>=x && px<=x+w && py>=y && py<=y+h; }
}

class IconButton {
  float x, y, w, h;
  String label;
  int iconType = 0; // 0=play, 1=reset, 2=save
  int bgColor = -1;
  boolean hasBgColor = false;
  IconButton(float x, float y, float w, float h, String label) {
    this.x=x; this.y=y; this.w=w; this.h=h; this.label=label;
  }
  IconButton(float x, float y, float w, float h, String label, int iconType) {
    this.x=x; this.y=y; this.w=w; this.h=h; this.label=label; this.iconType = iconType;
  }
  IconButton(float x, float y, float w, float h, String label, int iconType, int bgColor) {
    this.x=x; this.y=y; this.w=w; this.h=h; this.label=label; this.iconType = iconType; this.bgColor = bgColor; this.hasBgColor = true;
  }

  void draw() {
    stroke(60);
    strokeWeight(1.5);
    if (hasBgColor) fill(bgColor);
    else fill(255);
    rect(x, y, w, h, 10);

    // triangle play
    noStroke();
    fill(40);
    textSize(12);
    float gap = 6;
    float iconW = min(w, h) * 0.35;
    float labelW = textWidth(label);
    float groupW = iconW + gap + labelW;
    float groupX = x + (w - groupW) * 0.5;
    float cx = groupX + iconW * 0.5;
    float cy = y + h * 0.5;

    if (iconType == 1) {
      stroke(40);
      strokeWeight(2);
      float s = iconW * 0.45;
      line(cx - s, cy - s, cx + s, cy + s);
      line(cx - s, cy + s, cx + s, cy - s);
      noStroke();
    } else if (iconType == 2) {
      // disquet
      stroke(40);
      strokeWeight(1.5);
      float s = iconW * 0.9;
      float bx = cx - s * 0.5;
      float by = cy - s * 0.5;
      noFill();
      rect(bx, by, s, s, 2);
      line(bx + s*0.15, by + s*0.25, bx + s*0.85, by + s*0.25);
      rect(bx + s*0.2, by + s*0.45, s*0.6, s*0.35);
      noStroke();
    } else {
      float tri = iconW;
      triangle(cx - tri*0.35, cy - tri*0.5,
               cx - tri*0.35, cy + tri*0.5,
               cx + tri*0.55, cy);
    }

    fill(30);
    textAlign(LEFT, CENTER);
    text(label, groupX + iconW + gap, y + h*0.5);
  }

  boolean hit(float mx, float my) {
    return (mx>=x && mx<=x+w && my>=y && my<=y+h);
  }
}

class ToggleButton {
  float x, y, w, h;
  String label;
  boolean isOn = false;

  ToggleButton(float x, float y, float w, float h, String label) {
    this.x=x; this.y=y; this.w=w; this.h=h; this.label=label;
  }

  void draw() {
    stroke(70);
    strokeWeight(1.3);
    if (isOn) fill(210);
    else fill(255);
    rect(x, y, w, h, 8);

    fill(30);
    textAlign(CENTER, CENTER);
    textSize(12);
    text(label, x + w*0.5, y + h*0.52);
  }

  boolean hit(float mx, float my) {
    return (mx>=x && mx<=x+w && my>=y && my<=y+h);
  }
}

class CheckBox {
  float x, y, s;
  String label;
  boolean isOn = false;

  CheckBox(float x, float y, float s, String label) {
    this.x=x; this.y=y; this.s=s; this.label=label;
  }

  void draw() {
    stroke(70);
    strokeWeight(1.3);
    fill(255);
    rect(x, y, s, s, 3);
    if (isOn) {
      stroke(40);
      strokeWeight(2);
      line(x + 3, y + s*0.5, x + s*0.45, y + s - 3);
      line(x + s*0.45, y + s - 3, x + s - 3, y + 3);
    }
    fill(30);
    noStroke();
    textAlign(LEFT, CENTER);
    textSize(12);
    text(label, x + s + 8, y + s*0.5);
  }

  void mousePressed(float mx, float my) {
    if (mx>=x && mx<=x+s && my>=y && my<=y+s) isOn = !isOn;
  }
}

class Slider {
  float x, y, w, h;
  float minV, maxV;
  float value;
  String label;
  boolean dragging = false;

  Slider(float x, float y, float w, float h, float minV, float maxV, float value, String label) {
    this.x=x; this.y=y; this.w=w; this.h=h;
    this.minV=minV; this.maxV=maxV; this.value=constrain(value, minV, maxV);
    this.label=label;
  }

  void draw() {
    // label + valor
    fill(30);
    textAlign(CENTER, BOTTOM);
    textSize(12);
    text(label + "  " + nf(value, 0, 2), x + w*0.5, y - 4);

    // rail base
    float cy = y + h * 0.5;
    stroke(200);
    strokeWeight(6);
    line(x, cy, x + w, cy);

    // progress rail
    float t = map(value, minV, maxV, 0, 1);
    float kx = x + t * w;
    stroke(60, 140, 220);
    strokeWeight(6);
    line(x, cy, kx, cy);

    // knob
    noStroke();
    fill(255);
    ellipse(kx, cy, h*1.4, h*1.4);
    stroke(60, 140, 220);
    strokeWeight(2);
    noFill();
    ellipse(kx, cy, h*1.4, h*1.4);

    // small inner dot
    noStroke();
    fill(60, 140, 220);
    ellipse(kx, cy, h*0.5, h*0.5);

    // caixa invisible per facilitar clicar
    noFill();
    stroke(0, 0);
    rect(x, y, w, h);
  }

  void mousePressed(float mx, float my) {
    // zona sensible una mica més gran
    if (mx >= x && mx <= x+w && my >= y-8 && my <= y+h+8) {
      dragging = true;
      setFromMouse(mx);
    }
  }

  void mouseDragged(float mx, float my) {
    if (dragging) setFromMouse(mx);
  }

  void mouseReleased() {
    dragging = false;
  }

  void setFromMouse(float mx) {
    float t = constrain((mx - x) / w, 0, 1);
    value = lerp(minV, maxV, t);
  }
}
