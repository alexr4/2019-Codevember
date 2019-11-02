/*
http://paulbourke.net/geometry/circlesphere/
 A sphere may be defined parametrically in terms of (u,v)
 
 x = xo + r sin(theta) cos(phi)
 y = yo + r sin(theta) sin(phi)
 z = zo + r cos(theta) 
 
 Where 0 <= theta <  pi, and 0 <= phi <= 2Pi. 
 The convention in common usage is for lines of constant theta to run from one pole (phi = -pi/2 for the south pole) 
 to the other pole (phi = pi/2 for the north pole) and are usually refered to as lines of longitude. 
 Lines of constant phi are often refered to as lines of latitude, for example the equator is at phi = 0. 
 */
class Poly3D
{
  //variables
  PShape poly;
  PShape polyNormal;
  PShape wireframedHighPoly;
  PShape wireframedLowPoly; 
  PVector origin;
  float polyRadiusX;
  float polyRadiusY;
  float polyRadiusZ;
  int vertexNumberPerLongitude;
  int vertexNumberPerLatitude;
  int subdivisionNumber;
  ArrayList<PVector> fistVertexList;
  PVector[][] originalVertexList;
  PVector[][] originalUVList;
  ArrayList<PVector> vertexList;
  ArrayList<PVector> uvList;
  ArrayList<PVector> normalList;
  ArrayList<PVector> normalFaceList;
  ArrayList<PVector> centroidFaceList;

  PImage test;

  //Builder
  Poly3D(PVector origin_, float polyRadiusX_, float polyRadiusY, float polyRadiusZ, int vertexNumberPerLongitude_, int vertexNumberPerLatitude_, int subdivisionNumber_)
  {
    test = loadImage("noiseTexture.jpg");
    initPoly(origin_, polyRadiusX_, polyRadiusY, polyRadiusZ, vertexNumberPerLongitude_, vertexNumberPerLatitude_, subdivisionNumber_);
  }

  //Init Methods
  void initPoly(PVector origin_, float polyRadiusX_, float polyRadiusY, float polyRadiusZ, int vertexNumberPerLongitude_, int vertexNumberPerLatitude_, int subdivisionNumber_)
  {
    println("--");
    println("Init new mesh");
    initPolyVariables(origin_, polyRadiusX_, polyRadiusY, polyRadiusZ, vertexNumberPerLongitude_, vertexNumberPerLatitude_, subdivisionNumber_);
    computeFirstVertexList();
    computePoly();
    computePolyMesh();
    computePolyNormalMesh();
    computeWireframedLowPolyMesh();
    computeWireframedHighPolyMesh();
    println("New mesh has been init");
  }

  void createNewPoly(PVector origin_, float polyRadiusX_, float polyRadiusY, float polyRadiusZ, int vertexNumberPerLongitude_, int vertexNumberPerLatitude_, int subdivisionNumber_)
  {
    println("--");
    println("Delete old variables");
    vertexList.clear();
    uvList.clear();
    normalList.clear();
    normalFaceList.clear();
    centroidFaceList.clear();
    fistVertexList.clear();
    originalVertexList = null;
    poly = null;
    polyNormal = null;
    wireframedHighPoly = null;
    wireframedLowPoly = null;

    initPoly(origin_, polyRadiusX_, polyRadiusY, polyRadiusZ, vertexNumberPerLongitude_, vertexNumberPerLatitude_, subdivisionNumber_);
  }

  void initPolyVariables(PVector origin_, float polyRadiusX_, float polyRadiusY_, float polyRadiusZ_, int vertexNumberPerLongitude_, int vertexNumberPerLatitude_, int subdivisionNumber_)
  {
    println("\tInit mesh parameters");
    poly = createShape();
    polyNormal = createShape(GROUP);
    wireframedHighPoly = createShape();
    wireframedLowPoly = createShape();

    origin = origin_.get(); //new PVector(0, 0, 0);
    polyRadiusX = polyRadiusX_;//random(100, 300);
    polyRadiusY = polyRadiusY_;//random(100, 300);
    polyRadiusZ = polyRadiusZ_;//random(100, 200);
    vertexNumberPerLongitude = vertexNumberPerLongitude_;//round(random(3, 10));
    vertexNumberPerLatitude = vertexNumberPerLatitude_;//round(random(4, 10));
    subdivisionNumber = subdivisionNumber_;//round(random(3, 8));
    fistVertexList = new ArrayList<PVector>();
    vertexList = new ArrayList<PVector>();
    uvList = new ArrayList<PVector>();
    normalList = new ArrayList<PVector>();
    normalFaceList = new ArrayList<PVector>();
    centroidFaceList = new ArrayList<PVector>();
    originalVertexList = new PVector[vertexNumberPerLongitude][vertexNumberPerLatitude];
    originalUVList     = new PVector[vertexNumberPerLongitude][vertexNumberPerLatitude];
  }

  //Mesh computational Methods
  void computeFirstVertexList()
  {
    println("\tCompute low poly vertex");

    for (int i=0; i<vertexNumberPerLongitude; i++)
    {

      float eta = 0;
      //compute angle theta where eta < theta < (2PI/vertexNuber)*i
      float theta = map(i, 0, vertexNumberPerLongitude-1, 0, PI); //Longitude
      //theta = (theta + offsetTheta) % PI;

      for (int j=0; j<vertexNumberPerLatitude; j++)
      {
        float normj = (float)j / (float)(vertexNumberPerLatitude);//map(j, 0, vertexNumberPerLatitude-1, 0, TWO_PI)
        float phi = random(eta, normj * TWO_PI);//map(j, 0, vertexNumberPerLatitude-1, 0, TWO_PI); //latitude 
        //phi = (phi + offsetPHI) % TWO_PI;
        //find vertex position on the circle C with x = cos(theta) * radius & y = sin(theta) * radius;
        float x = origin.x + sin(theta) * cos(phi) * polyRadiusX;
        float y = origin.y + sin(theta) * sin(phi) * polyRadiusY;
        float z = origin.z + cos(theta) * polyRadiusZ;

        PVector polyVertex = new PVector(x, y, z);
        PVector uv = new PVector(theta/PI, phi/TWO_PI);


        //add computed vertex to the list
        fistVertexList.add(polyVertex);
        originalVertexList[i][j] = polyVertex;
        originalUVList[i][j] = uv;
        //eta = theta
        eta = phi;
      }
    }
    println("\tLow poly has been compute with : "+fistVertexList.size()+" vertex");
  }

  void computePoly()
  {
    println("\tCompute high poly sub division of "+subdivisionNumber);
    for (int i =0; i<vertexNumberPerLongitude; i++)
    {
      for (int j=0; j<vertexNumberPerLatitude; j++)
      {
        int long0 = i;
        int long1 = i;
        int lat0 = j;
        int lat1 = j;

        if (i < vertexNumberPerLongitude-1)
        {
          long1 = i+1;
        } else
        {
          long1 = 0;
        }

        if (j < vertexNumberPerLatitude-1)
        {
          lat1 = j+1;
        } else
        {
          lat1 = 0;
        }


        PVector v0 = originalVertexList[long0][lat0];
        PVector v1 = originalVertexList[long0][lat1];
        PVector v2 = originalVertexList[long1][lat0];
        PVector v3 = originalVertexList[long1][lat1];


        PVector uv0 = originalUVList[long0][lat0];
        PVector uv1 = originalUVList[long0][lat1];
        PVector uv2 = originalUVList[long1][lat0];
        PVector uv3 = originalUVList[long1][lat1];

        /*Subdivide from gravity center */
        subdividePolyFromGravityCenter(v0, v1, v2, uv0, uv1, uv2, subdivisionNumber);
        subdividePolyFromGravityCenter(v2, v1, v3, uv2, uv1, uv3, subdivisionNumber);

        /*Subdivide from mediane*/
        //subdivideTriangle(v0, v1, v2, subdivisionNumber);
        //subdivideTriangle(v2, v1, v3, subdivisionNumber);
      }
    }
    println("\tHigh poly has been compute with : "+vertexList.size()+" vertex");
  }

  void subdivideLine(PVector a, PVector b, int level)
  {
    if (level <= 0)
    {
      vertexList.add(a);
      vertexList.add(b);
    } else
    {
      PVector ab = findMidPoint(a, b);
      level --;
      subdivideLine(a, ab, level);
      subdivideLine(ab, b, level);
    }
  }

  void subdivideTriangle(PVector a, PVector b, PVector c, int level)
  {
    if (level <= 0)
    {
      vertexList.add(a);
      vertexList.add(b);
      vertexList.add(c);

      PVector ab = PVector.sub(b, a);
      PVector ac = PVector.sub(c, a);

      //find perpendicular vector to the plane
      PVector crossabac = ab.cross(ac); //normal perpendicular vector to face
      //crossabac.normalize(); //compute normals
      crossabac.mult(-1); //invert normals

      normalList.add(crossabac);
      normalList.add(crossabac);
      normalList.add(crossabac);

      centroidFaceList.add(findGravityPoint(a, b, c));
      normalFaceList.add(crossabac);
    } else
    {
      PVector ca = findMidPoint(c, a);
      PVector ab = findMidPoint(a, b);
      PVector bc = findMidPoint(b, c);

      level --;

      subdivideTriangle(c, ca, bc, level);
      subdivideTriangle(ca, a, ab, level);
      subdivideTriangle(ab, b, bc, level);
      subdivideTriangle(ca, ab, bc, level);
    }
  }

  void subdividePolyFromGravityCenter(PVector a, PVector b, PVector c, PVector uva, PVector uvb, PVector uvc, int level)
  {
    if (level <= 0)
    {
      vertexList.add(a);
      vertexList.add(b);
      vertexList.add(c);

      uvList.add(uva);
      uvList.add(uvb);
      uvList.add(uvc);

      PVector ab = PVector.sub(b, a);
      PVector ac = PVector.sub(c, a);

      //find perpendicular vector to the plane
      PVector crossabac = ab.cross(ac); //normal perpendicular vector to face
      PVector centroid = findGravityPoint(a, b, c);

      //compute Face orientation
      PVector n = crossabac.get();
      n.setMag(5);
      n.add(centroid);
      float distON = PVector.dist(n, origin);
      float distOC = PVector.dist(centroid, origin);

      if (distON < distOC)
      {
        crossabac.mult(-1); //invert normals
      } else
      {
      }

      normalList.add(crossabac);
      normalList.add(crossabac);
      normalList.add(crossabac);

      centroidFaceList.add(centroid);
      normalFaceList.add(crossabac);
    } else
    {
      PVector gabc = findGravityPoint(a, b, c);
      PVector uvgabc = findGravityPoint(uva, uvb, uvc);
      //uvgabc.normalize();
      level --;

      subdividePolyFromGravityCenter(a, gabc, b, uva, uvgabc, uvb, level);
      subdividePolyFromGravityCenter(c, gabc, a, uvc, uvgabc, uva, level);
      subdividePolyFromGravityCenter(gabc, c, b, uvgabc, uvc, uvb, level);
    }
  }

  //GPU Mesh builder
  void computePolyMesh()
  {
    println("\tCreate & bind high poly mesh to GPU");

    poly.beginShape(TRIANGLES);
    poly.noStroke();
    poly.fill(5);
    poly.textureMode(NORMAL);
    //poly.texture(test);
    for (int i=0; i<vertexList.size (); i++)
    {

      PVector v0 = vertexList.get(i);
      PVector uv0 = uvList.get(i);
      PVector nV0 = normalList.get(i);

      float r = map(nV0.x, 0, 1, 0, 225);
      float v = map(nV0.y, 0, 1, 0, 225);
      float b = map(nV0.z, 0, 1, 0, 225);


      poly.normal(nV0.x, nV0.y, nV0.z);
      //poly.fill(r, v, b);
      //poly.fill(uv0.x * 255, uv0.y * 255, 0.0);
      poly.vertex(v0.x, v0.y, v0.z, uv0.x, uv0.y);
    }
    poly.endShape();
  }

  void computePolyNormalMesh()
  {
    println("\tCreate & bind high poly normals mesh to GPU");
    for (int i=0; i<normalFaceList.size (); i++)
    {
      PShape normal = createShape();

      PVector o = centroidFaceList.get(i).get();
      PVector n = normalFaceList.get(i).get();
      float noiseScale = noise(i * .1) * 10 + 5;
      n.setMag(10);
      n.add(o);

      normal.beginShape(LINES);
      normal.stroke(255, 0, 255);
      normal.vertex(o.x, o.y, o.z);
      normal.stroke(0, 255, 255);
      normal.vertex(n.x, n.y, n.z);
      normal.endShape(CLOSE);

      polyNormal.addChild(normal);
    }
  }

  void computeWireframedHighPolyMesh()
  {
    float m = map(mouseX, 0, width, -1.0, 1.0);
    println("\tCreate & bind wireframed high poly mesh to GPU");
    PVector from = PVector.sub(origin, new PVector(0, 0, 500)).normalize();
    wireframedHighPoly.beginShape(TRIANGLES);
    wireframedHighPoly.noFill();
    wireframedHighPoly.stroke(255);
    wireframedHighPoly.strokeWeight(1.0);
    for (int i=0; i<vertexList.size (); i++)
    {
      PVector v0 = vertexList.get(i);
      PVector normal = normalList.get(i);

      wireframedHighPoly.vertex(v0.x, v0.y, v0.z);
    }
    wireframedHighPoly.endShape();
  }

  void computeWireframedLowPolyMesh()
  {
    println("\tCreate & bind wireframed low poly mesh to GPU");
    wireframedLowPoly.beginShape(QUAD);
    wireframedLowPoly.noFill();
    wireframedLowPoly.stroke(255);
    for (int i =0; i<vertexNumberPerLongitude; i++)
    {
      for (int j=0; j<vertexNumberPerLatitude; j++)
      {
        int long0 = i;
        int long1 = i;
        int lat0 = j;
        int lat1 = j;

        if (i < vertexNumberPerLongitude-1)
        {
          long1 = i+1;
        } else
        {
          long1 = 0;
        }

        if (j < vertexNumberPerLatitude-1)
        {
          lat1 = j+1;
        } else
        {
          lat1 = 0;
        }

        PVector vert0 = originalVertexList[long0][lat0];
        PVector vert1 = originalVertexList[long0][lat1];
        PVector vert2 = originalVertexList[long1][lat0];
        PVector vert3 = originalVertexList[long1][lat1];

        PVector nV0 = vert0.get();
        PVector nV1 = vert1.get();
        PVector nV2 = vert2.get();
        PVector nV3 = vert3.get();
        nV0.normalize();
        nV1.normalize();
        nV2.normalize();
        nV3.normalize();

        float r0 = map(nV0.x, 0, 1, 0, 225);
        float v0 = map(nV0.y, 0, 1, 0, 225);
        float b0 = map(nV0.z, 0, 1, 0, 225);
        float r1 = map(nV1.x, 0, 1, 0, 225);
        float v1 = map(nV1.y, 0, 1, 0, 225);
        float b1 = map(nV1.z, 0, 1, 0, 225);
        float r2 = map(nV2.x, 0, 1, 0, 225);
        float v2 = map(nV2.y, 0, 1, 0, 225);
        float b2 = map(nV2.z, 0, 1, 0, 225);
        float r3 = map(nV3.x, 0, 1, 0, 225);
        float v3 = map(nV3.y, 0, 1, 0, 225);
        float b3 = map(nV3.z, 0, 1, 0, 225);

        //wireframedLowPoly.stroke(r0, v0, b0);
        wireframedLowPoly.vertex(vert0.x, vert0.y, vert0.z);
        //wireframedLowPoly.stroke(r1, v1, b1);
        wireframedLowPoly.vertex(vert1.x, vert1.y, vert1.z);
        //wireframedLowPoly.stroke(r2, v2, b2);
        wireframedLowPoly.vertex(vert3.x, vert3.y, vert3.z);
        //wireframedLowPoly.stroke(r3, v3, b3);
        wireframedLowPoly.vertex(vert2.x, vert2.y, vert2.z);
      }
    }

    wireframedLowPoly.endShape();
  }

  //Math methods
  PVector findMidPoint(PVector a, PVector b) {
    PVector midPoint = PVector.add(a, b);
    midPoint.mult(0.5);

    return midPoint;
  }

  PVector findGravityPoint(PVector a, PVector b, PVector c)
  {
    PVector gravityCenter = new PVector();
    gravityCenter.add(a);
    gravityCenter.add(b);
    gravityCenter.add(c);
    gravityCenter.div(3);

    return gravityCenter;
  }

  PVector findGravityPoint(PVector a, PVector b, PVector c, PVector d)
  {
    PVector gravityCenter = new PVector();
    gravityCenter.add(a);
    gravityCenter.add(b);
    gravityCenter.add(c);
    gravityCenter.add(d);
    gravityCenter.div(4);

    return gravityCenter;
  }
}
