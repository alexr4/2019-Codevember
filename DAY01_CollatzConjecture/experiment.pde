void initCollatz() {
  randomSeed(millis() + 10000);
  collatzList = new ArrayList<CollatzOperator>();
  long startingPoint = randomLong(6171, 8400511L);
  long offset = randomLong(1L, 10000L);
  int numberOfbranch = round(random(50, 150));
  for (int i=0; i<numberOfbranch; i++) {
    long number = startingPoint + i * offset;
    float randomAngle = random(0.1, 0.01);
    pushMatrix();
    translate(width/2, height/2);

    CollatzOperator co = new CollatzOperator(number, HALF_PI * randomAngle, 10.0);
    collatzList.add(co);
    popMatrix();
  }
}

public long randomLong(long min, long max) {
  long val = min + (long) (Math.random() * (max - min));
  return val;
}
