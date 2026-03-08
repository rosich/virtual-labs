// --- Paràmetres model ---
int cols = 64;
int rows = 64;
int[][] spins;
float temperature = 2.269;
float J = 1.0;
float h = 0.0;
boolean running = true;
int stepCount = 0;

// --- Layout general ---
int boardBaseW = 650; // amplada original del sketch
int sideMargin = 20;
int panelW = 360;
int panelGap = 50;
int panelGapY = 44;
int titleOffsetY = -12;
int plotTitleSize = 13;
int plotTextSize = 12;
int rightMargin = 50;
int windowH = 820;
int windowW = boardBaseW + panelGap + panelW + rightMargin;
int boardFooter = 120 + 90; // espai reservat (com abans amb histograma)

// --- Slider temperatura ---
float sliderX, sliderY, sliderW, sliderH;
float tempMin = 0.0001, tempMax = 100.0;
boolean draggingSlider = false;

// --- Slider camp extern h ---
float hSliderX, hSliderY, hSliderW, hSliderH;
float hMin = 0.001, hMax = 1.0;
boolean draggingHSlider = false;

// --- Botons ---
float btnX, btnY, btnW, btnH, btnGap;
float resetX, resetY, stopX, stopY;
float snapX, snapY;
float sizeBtnX, sizeBtnY, sizeBtnW, sizeBtnH, sizeBtnGap;
int[] sizeOptions = {8, 16, 32, 64, 128, 256};

// --- Gràfic de magnetització ---
int graphW = 300;
int graphH = 110;
int maxData = 300;
ArrayList<Float> magHistory = new ArrayList<Float>();

// --- Energia i històries ---
ArrayList<Float> energyHistory = new ArrayList<Float>();
ArrayList<Float> energyFullHistory = new ArrayList<Float>();

// --- Històries llargues ---
int maxHistData = 12000;
ArrayList<Float> magFullHistory = new ArrayList<Float>();

// --- Chi ---

// --- Guardar dades ---
PrintWriter output;

void setup() {
  spins = new int[cols][rows];
  randomizeSpins(); // inicialització aleatòria
  
  // Slider dimensions and position (baixa slider abaix de tot)
  sliderW = 220;
  sliderH = 18;
  sliderX = 30;
  sliderY = height - sliderH - 100;
  hSliderW = 220;
  hSliderH = 18;
  hSliderX = sliderX + sliderW + 80;
  hSliderY = sliderY;

  layoutButtons();

  output = createWriter("magnetitzacio.txt");
  frameRate(30);
}

void settings() {
  size(windowW, windowH); // Dona espai per al panell dret
}

void draw() {
  background(30);
  layoutButtons();
  displaySpins();

  // Simulació
  if (running) {
    for (int n = 0; n < cols*rows; n++) {
      isingStep();
    }
  }

  // Calcula magnetització
  float M = calcMagnetization();
  float E = calcEnergyPerSpin();
  if (running) {
    magHistory.add(M);
    if (magHistory.size() > maxData) magHistory.remove(0);

    magFullHistory.add(M);
    if (magFullHistory.size() > maxHistData) magFullHistory.remove(0);

    energyHistory.add(E);
    if (energyHistory.size() > maxData) energyHistory.remove(0);

    energyFullHistory.add(E);
    if (energyFullHistory.size() > maxHistData) energyFullHistory.remove(0);

    float[] mStats = meanAndMeanSq(magFullHistory);
    float[] eStats = meanAndMeanSq(energyFullHistory);
    float N = cols * rows;
    float chi = (mStats[1] - mStats[0]*mStats[0]) * N / temperature;

    stepCount++;
    // Escriu fitxer (per frame)
    output.println(stepCount + "\t" + M + "\t" + E + "\t" + chi);
  }

  // --- PANELL DRET ---
  int panelX = boardBaseW + panelGap;
  int y = 30;
  drawMagnetizationGraph(panelX, y, panelW, graphH);
  y += graphH + panelGapY;
  drawEnergyGraph(panelX, y, panelW, graphH);

  // --- SLIDER ---
  drawTempSlider();
  drawHSlider();

  // --- BOTONS ---
  drawButtons();

  // --- ETIQUETES ---
  fill(255);
  textSize(15);
  textAlign(LEFT, CENTER);
  text("Temperatura T:", sliderX, sliderY - 32);
  text("Camp extern h:", hSliderX, hSliderY - 32);
  text("M: " + nf(M,1,4) + "   E/N: " + nf(E,1,4), sliderX, sliderY + sliderH + 40);

  // --- PAUSA ---
  if (!running) {
    fill(255, 80);
    textSize(36);
    textAlign(CENTER, CENTER);
    text("SIMULACIÓ PAUSADA", width/2, height/2);
    textSize(12);
    textAlign(LEFT, TOP);
  }
}

void layoutButtons() {
  btnW = 110;
  btnH = 28;
  btnGap = 10;
  btnX = boardBaseW + panelGap;
  btnY = height - btnH - 360;
  resetX = btnX;
  resetY = btnY;
  stopX = btnX + btnW + btnGap;
  stopY = btnY;
  snapX = btnX + (btnW + btnGap) * 2;
  snapY = btnY;

  sizeBtnW = 50;
  sizeBtnH = 24;
  sizeBtnGap = 10;
  sizeBtnX = windowW - rightMargin - (3 * sizeBtnW + 2 * sizeBtnGap);
  sizeBtnY = btnY - sizeBtnH - 8 + 140;
}

void drawButtons() {
  drawButton(resetX, resetY, btnW, btnH, "Reset");
  String stopLabel = running ? "Stop" : "Start";
  drawButton(stopX, stopY, btnW, btnH, stopLabel);
  drawButton(snapX, snapY, btnW, btnH, "Captura pantalla");
  fill(200);
  textSize(12);
  textAlign(LEFT, BOTTOM);
  text("Dimensió tauler (NxN)", sizeBtnX, sizeBtnY - 4);
  textAlign(LEFT, TOP);
  for (int i = 0; i < sizeOptions.length; i++) {
    int row = i / 3;
    int col = i % 3;
    float x = sizeBtnX + col * (sizeBtnW + sizeBtnGap);
    float y = sizeBtnY + row * (sizeBtnH + sizeBtnGap);
    boolean active = (sizeOptions[i] == cols);
    drawSizeButton(x, y, sizeBtnW, sizeBtnH, str(sizeOptions[i]), active);
  }
}

void drawButton(float x, float y, float w, float h, String label) {
  boolean hover = overRect(x, y, w, h);
  fill(hover ? 90 : 70);
  stroke(140);
  rect(x, y, w, h, 6);
  fill(240);
  textSize(12);
  textAlign(CENTER, CENTER);
  text(label, x + w/2, y + h/2 + 1);
  textAlign(LEFT, TOP);
}

void drawSizeButton(float x, float y, float w, float h, String label, boolean active) {
  boolean hover = overRect(x, y, w, h);
  if (active) fill(110, 160, 110);
  else fill(hover ? 90 : 70);
  stroke(active ? 200 : 140);
  rect(x, y, w, h, 6);
  fill(240);
  textSize(12);
  textAlign(CENTER, CENTER);
  text(label, x + w/2, y + h/2 + 1);
  textAlign(LEFT, TOP);
}

boolean overRect(float x, float y, float w, float h) {
  return mouseX >= x && mouseX <= x + w && mouseY >= y && mouseY <= y + h;
}

void displaySpins() {
  float topMargin = 20;
  float w = (boardBaseW - 30) / float(cols);
  float h = w;
  if (cols <= 32) {
    stroke(70);
  } else {
    noStroke();
  }
  for (int i = 0; i < cols; i++) {
    for (int j = 0; j < rows; j++) {
      // Colors estil modern (pots ajustar)
      if (spins[i][j] == 1) fill(230, 60, 60); // Spin +1 (vermell clar)
      else fill(30, 80, 160);                  // Spin -1 (blau)
      //stroke(50);
      rect(sideMargin + i*w, topMargin + j*h, w, h);
    }
  }
}

void isingStep() {
  int i = int(random(cols));
  int j = int(random(rows));
  int s = spins[i][j];
  int sum_neigh = spins[(i+1)%cols][j] + spins[(i-1+cols)%cols][j] +
                  spins[i][(j+1)%rows] + spins[i][(j-1+rows)%rows];
  float dE = 2 * s * (J*sum_neigh + h);
  if (dE < 0 || random(1) < exp(-dE/temperature)) {
    spins[i][j] *= -1;
  }
}

float calcMagnetization() {
  int sum = 0;
  for (int i = 0; i < cols; i++) {
    for (int j = 0; j < rows; j++) {
      sum += spins[i][j];
    }
  }
  return sum / float(cols * rows);
}

float calcEnergyPerSpin() {
  float E = 0;
  for (int i = 0; i < cols; i++) {
    for (int j = 0; j < rows; j++) {
      int s = spins[i][j];
      int right = spins[(i+1)%cols][j];
      int down = spins[i][(j+1)%rows];
      E += -J * s * (right + down) - h * s;
    }
  }
  return E / float(cols * rows);
}

// --- SLIDER ---
void drawTempSlider() {
  fill(60);
  stroke(150);
  rect(sliderX, sliderY, sliderW, sliderH, 9);
  float tLogMin = log(tempMin);
  float tLogMax = log(tempMax);
  float pos = map(log(temperature), tLogMin, tLogMax, sliderX, sliderX + sliderW);
  fill(230, 180, 80);
  noStroke();
  ellipse(pos, sliderY + sliderH / 2, sliderH, sliderH);
  fill(255);
  textAlign(LEFT, CENTER);
  textSize(13);
  //text("Temperatura", sliderX, sliderY - 8);
  textAlign(CENTER, BOTTOM);
  text(nf(temperature, 1, 4) + " K", pos, sliderY - 4);
  textAlign(LEFT, TOP);
  text(nf(tempMin,1,4), sliderX, sliderY + sliderH + 2);
  textAlign(RIGHT, TOP);
  text(nf(tempMax,1,1), sliderX + sliderW, sliderY + sliderH + 2);

  // Marca temperatura crítica
  float tc = 2.269;
  float tcritX = map(log(tc), log(tempMin), log(tempMax), sliderX, sliderX + sliderW);
  stroke(255, 80, 80);
  strokeWeight(2);
  line(tcritX, sliderY, tcritX, sliderY + sliderH);
  fill(255, 80, 80);
  noStroke();
  textSize(12);
  textAlign(CENTER, TOP);
  text("Tc", tcritX, sliderY + sliderH + 4);
  strokeWeight(1);
}

void drawHSlider() {
  fill(60);
  stroke(150);
  rect(hSliderX, hSliderY, hSliderW, hSliderH, 9);
  float logMin = log(hMin);
  float logMax = log(hMax);
  float hSafe = max(h, hMin);
  float pos = map(log(hSafe), logMin, logMax, hSliderX, hSliderX + hSliderW);
  fill(120, 200, 240);
  noStroke();
  ellipse(pos, hSliderY + hSliderH / 2, hSliderH, hSliderH);
  fill(255);
  textAlign(CENTER, BOTTOM);
  textSize(13);
  text(nf(h, 1, 3), pos, hSliderY - 4);
  textAlign(LEFT, TOP);
  textSize(12);
  text(nf(hMin,1,3), hSliderX, hSliderY + hSliderH + 2);
  textAlign(RIGHT, TOP);
  text(nf(hMax,1,3), hSliderX + hSliderW, hSliderY + hSliderH + 2);
  textAlign(LEFT, TOP);
}

void mousePressed() {
  if (overRect(resetX, resetY, btnW, btnH)) {
    randomizeSpins();
    magHistory.clear();
    magFullHistory.clear();
    energyHistory.clear();
    energyFullHistory.clear();
    stepCount = 0;
    resetOutput();
    return;
  }
  if (overRect(stopX, stopY, btnW, btnH)) {
    running = !running;
    return;
  }
  if (overRect(snapX, snapY, btnW, btnH)) {
    saveFrame("snapshot-####.png");
    return;
  }
  for (int i = 0; i < sizeOptions.length; i++) {
    int row = i / 3;
    int col = i % 3;
    float x = sizeBtnX + col * (sizeBtnW + sizeBtnGap);
    float y = sizeBtnY + row * (sizeBtnH + sizeBtnGap);
    if (overRect(x, y, sizeBtnW, sizeBtnH)) {
      setSystemSize(sizeOptions[i]);
      return;
    }
  }
  float tLogMin = log(tempMin);
  float tLogMax = log(tempMax);
  float pos = map(log(temperature), tLogMin, tLogMax, sliderX, sliderX + sliderW);
  if (dist(mouseX, mouseY, pos, sliderY + sliderH/2) < sliderH) {
    draggingSlider = true;
  }
  float hLogMin = log(hMin);
  float hLogMax = log(hMax);
  float hSafe = max(h, hMin);
  float hPos = map(log(hSafe), hLogMin, hLogMax, hSliderX, hSliderX + hSliderW);
  if (dist(mouseX, mouseY, hPos, hSliderY + hSliderH/2) < hSliderH) {
    draggingHSlider = true;
  }
}
void mouseDragged() {
  if (draggingSlider) {
    float tLogMin = log(tempMin);
    float tLogMax = log(tempMax);
    float logT = map(mouseX, sliderX, sliderX + sliderW, tLogMin, tLogMax);
    temperature = constrain(exp(logT), tempMin, tempMax);
  }
  if (draggingHSlider) {
    float hLogMin = log(hMin);
    float hLogMax = log(hMax);
    float logH = map(mouseX, hSliderX, hSliderX + hSliderW, hLogMin, hLogMax);
    h = constrain(exp(logH), hMin, hMax);
  }
}
void mouseReleased() {
  draggingSlider = false;
  draggingHSlider = false;
}

// --- ENERGIA ---
void drawMagnetizationGraph(int x, int y, int w, int h) {
  fill(40);
  noStroke();
  rect(x, y, w, h);
  if (magHistory.size() < 2) return;

  if (cols < 64) drawPlotGrid(x, y, w, h, 100);

  // Traç de M
  noFill();
  stroke(180, 240, 120);
  beginShape();
  for (int i = 0; i < magHistory.size(); i++) {
    float val = magHistory.get(i);
    float px = map(i, 0, maxData-1, x, x+w);
    float py = map(val, -1, 1, y+h, y);
    vertex(px, py);
  }
  endShape();

  // Eix Y=0
  stroke(120);
  float zeroY = map(0, -1, 1, y + h, y);
  line(x, zeroY, x + w, zeroY);

  // Eixos (a sobre del traç)
  stroke(220);
  line(x, y, x, y + h);
  line(x, y + h, x + w, y + h);

  // Etiquetes
  fill(200);
  textSize(plotTitleSize);
  textAlign(LEFT, TOP);
  float mNow = magHistory.get(magHistory.size()-1);
  text("Magnetització (M/N): " + nf(mNow,1,4), x+5, y + titleOffsetY);
  textSize(plotTextSize);
  textAlign(RIGHT, CENTER);
  stroke(180);
  line(x-3, y+8, x+3, y+8);
  text("+1", x-6, y+8);
  line(x-3, y+h*0.5, x+3, y+h*0.5);
  text("0", x-6, y+h*0.5);
  line(x-3, y+h-14, x+3, y+h-14);
  text("-1", x-6, y+h-14);
  textAlign(LEFT, TOP);
  text("pas", x+w-16, y+h+2);
  textAlign(LEFT, TOP);
  textSize(plotTextSize);
}

void drawEnergyGraph(int x, int y, int w, int h) {
  fill(40);
  noStroke();
  rect(x, y, w, h);
  if (energyHistory.size() < 2) return;

  if (cols < 64) drawPlotGrid(x, y, w, h, 100);

  float[] mm = minMax(energyHistory);
  float minE = mm[0];
  float maxE = mm[1];
  float pad = 0.1;
  minE -= pad;
  maxE += pad;
  // Eixos
  stroke(120);
  line(x, y, x, y + h);
  line(x, y + h, x + w, y + h);
  // Eix E=0 (eliminat)
  noFill();
  stroke(120, 200, 240);
  beginShape();
  for (int i = 0; i < energyHistory.size(); i++) {
    float val = energyHistory.get(i);
    float px = map(i, 0, maxData-1, x, x+w);
    float py = map(val, minE, maxE, y+h, y);
    vertex(px, py);
  }
  endShape();
  fill(200);
  textSize(plotTitleSize);
  textAlign(LEFT, TOP);
  float eNow = energyHistory.get(energyHistory.size()-1);
  text("Energia per spin (E/N): " + nf(eNow,1,4), x+5, y + titleOffsetY);
  textSize(plotTextSize);
  textAlign(RIGHT, CENTER);
  stroke(180);
  line(x-3, y+8, x+3, y+8);
  text(nf(maxE,1,3), x-6, y+8);
  line(x-3, y+h*0.5, x+3, y+h*0.5);
  text(nf((minE+maxE)*0.5,1,3), x-6, y+h*0.5);
  line(x-3, y+h-14, x+3, y+h-14);
  text(nf(minE,1,3), x-6, y+h-14);
  textAlign(LEFT, TOP);
  text("pas", x+w-16, y+h+2);
  textAlign(LEFT, TOP);
  textSize(plotTextSize);
}

// --- CHI I C ---
float[] meanAndMeanSq(ArrayList<Float> data) {
  float mean = 0;
  float meanSq = 0;
  int n = data.size();
  if (n == 0) return new float[] {0, 0};
  for (int i = 0; i < n; i++) {
    float v = data.get(i);
    mean += v;
    meanSq += v * v;
  }
  mean /= n;
  meanSq /= n;
  return new float[] {mean, meanSq};
}

float[] minMax(ArrayList<Float> data) {
  if (data.size() == 0) return new float[] {0, 1};
  float minV = data.get(0);
  float maxV = data.get(0);
  for (int i = 1; i < data.size(); i++) {
    float v = data.get(i);
    if (v < minV) minV = v;
    if (v > maxV) maxV = v;
  }
  return new float[] {minV, maxV};
}

void drawPlotGrid(int x, int y, int w, int h, int gridGray) {
  stroke(gridGray);
  strokeWeight(1);
  // Línies alineades amb eixos i ticks principals
  int vLines = 10;
  int hLines = 6;
  for (int i = 0; i <= vLines; i++) {
    float gx = map(i, 0, vLines, x, x + w);
    line(gx, y, gx, y + h);
  }
  for (int j = 0; j <= hLines; j++) {
    float gy = map(j, 0, hLines, y, y + h);
    line(x, gy, x + w, gy);
  }
}

// --- Controls ---
void keyPressed() {
  if (key == 'q') temperature += 0.1;
  if (key == 'a') temperature -= 0.1;
  temperature = constrain(temperature, tempMin, tempMax);
  if (key == ' ') running = !running;
  if (key == 'r' || key == 'R') {
    randomizeSpins();
    magHistory.clear();
    magFullHistory.clear();
    energyHistory.clear();
    energyFullHistory.clear();
    stepCount = 0;
    resetOutput();
  }
}

void randomizeSpins() {
  for (int i = 0; i < cols; i++) {
    for (int j = 0; j < rows; j++) {
      spins[i][j] = random(1) < 0.5 ? 1 : -1;
    }
  }
}

void setSystemSize(int n) {
  cols = n;
  rows = n;
  spins = new int[cols][rows];
  randomizeSpins();
  magHistory.clear();
  magFullHistory.clear();
  energyHistory.clear();
  energyFullHistory.clear();
  stepCount = 0;
  resetOutput();
}

void resetOutput() {
  output.flush();
  output.close();
  output = createWriter("magnetitzacio.txt");
}

// --- Tancar fitxer en sortir ---
void exit() {
  output.flush();
  output.close();
  super.exit();
}
