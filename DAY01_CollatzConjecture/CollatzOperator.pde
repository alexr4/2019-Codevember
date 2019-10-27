class CollatzOperator {
  long startingPoint;
  int step;
  ArrayList<PVector> vertList;
  float angle;
  float len;

  CollatzOperator(long startingPoint, float angle, float len) {
    init(startingPoint, angle, len);
    feedCollatz(startingPoint);
  }

  void init(long startingPoint, float angle, float len) {
    this.startingPoint = startingPoint; 
    this.angle = angle;
    this.len = len;
    vertList = new ArrayList<PVector>();
  }

  void feedCollatz(long number) {
    ArrayList<Long> valueList = new ArrayList<Long>();
    do {
      valueList.add(number);
      number = collatz(number);
      step ++;

      //println(startNumber);
    } while (number != 1);
    Collections.reverse(valueList);

    PVector location = new PVector();
    float xLimit = 0.75;
    float zLimit = 0.75;
    float yLimit = 0.15;
    PVector direction = new PVector(random(-xLimit, xLimit), random(-1, yLimit), random(-zLimit, zLimit)).normalize().mult(len);//PVector.random3D().mult(len);//new PVector(0, -len);
    for (int i=0; i<valueList.size(); i++) {
      long value = valueList.get(i);
      float orientation = (value % 2 == 0) ? -1.0 : 1.0;

      //PVector toDir = new PVector();
      direction = direction.copy();
      direction.rotate(angle * orientation);
      location.add(direction);
      vertList.add(location.copy());

      //rotate(angle * orientation);
      //line(0, 0, 0, -len);
      //translate(0, -len);
      //stroke(255);
    }
    //println("steps: "+step);
  }

  long collatz(long number) {
    if (number % 2 == 0) {
      return number / 2;
    } else {
      return (3 * number + 1) / 4;
    }
  }


  void drawShape(PGraphics ctx) {
    ctx.noFill();
    ctx.stroke(255);
    ctx.beginShape();
    for (PVector v : vertList) {
      ctx.vertex(v.x, v.y, v.z);
    }
    ctx.endShape();
  }

  void drawBox(PGraphics ctx) {
    ctx.fill(255);
    ctx.noStroke();
    for (int i=0; i<vertList.size(); i++) {
      PVector vert = vertList.get(i);
      PVector next = (i < vertList.size() - 1) ? vertList.get(i + 1) : vertList.get(i - 1).copy().mult(1);

      PVector v0tov1 = PVector.sub(next, vert);
      PVector n = v0tov1.normalize();

      //compute angle between two vectors
      PVector v0 = new PVector(0, 1, 0);
      PVector v1 = v0tov1.copy().normalize();

      float v0Dotv1 = PVector.dot(v0, v1);
      float phi = acos(v0Dotv1);
      PVector axis = v0.cross(v1);
      //println(degrees(phi), axis);

      ctx.pushMatrix();
      ctx.translate(vert.x, vert.y, vert.z);
      ctx.rotate(phi, axis.x, axis.y, axis.z); 
      ctx.box(len * 0.5, len, len * 0.5);
      ctx.popMatrix();
    }
  }

  void drawAnimatedBox(PGraphics ctx, float normTime, float normSpeedAnimation, int repetition) {
    float normTimeSmooth = smoothstep(0.0, 0.25, normTime);
    float thickness = 0.05;
    float smoothness = 0.1;
    int limit = floor(normTime * vertList.size());
    ctx.noStroke();
    for (int i=0; i<limit; i++) {
      float normIndex = (float)i / (float)limit;
      PVector vert = vertList.get(i);
      PVector next = (i < vertList.size() - 1) ? vertList.get(i + 1) : vertList.get(i - 1).copy().mult(1);

      PVector v0tov1 = PVector.sub(next, vert);
      PVector n = v0tov1.normalize();

      //compute angle between two vectors
      PVector v0 = new PVector(0, 1, 0);
      PVector v1 = v0tov1.copy().normalize();

      float v0Dotv1 = PVector.dot(v0, v1);
      float phi = acos(v0Dotv1);
      PVector axis = v0.cross(v1);
      //println(degrees(phi), axis);
      
      float boxTickness = map(sin(normIndex * TWO_PI * 0.25), -1.0, 1.0, len * 0.5, len * 0.2) * normTimeSmooth;
      float boxLen      = len * normTimeSmooth;

      if (i == limit-1) {
        ctx.fill(2, 242, 184);
      } else {
        float modIndex = (normIndex * repetition) % 1.0;
        float animatedBranch = smoothstep(normSpeedAnimation - thickness - smoothness, normSpeedAnimation - thickness, modIndex) * (1.0 - smoothstep(normSpeedAnimation + thickness, normSpeedAnimation + thickness + smoothness, modIndex));

        float easing = NormalEasing.outQuartic(normIndex);

        color col = lerpColor(color(0, 87, 255), color(255), easing);
        col = lerpColor(col, color(52, 127, 255), animatedBranch);


        ctx.fill(col);
      }
      ctx.pushMatrix();
      ctx.translate(vert.x, vert.y, vert.z);
      ctx.rotate(phi, axis.x, axis.y, axis.z); 
      ctx.box(boxTickness, boxLen, boxTickness);
      ctx.popMatrix();
    }
  }
}
