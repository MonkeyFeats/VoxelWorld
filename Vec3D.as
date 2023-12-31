//Vec3DClass.as
 
class Vec3f
{
    float x;
    float y;
    float z;
   
    Vec3f(){}
   
    Vec3f(float _x, float _y, float _z)
    {
        x = _x;
        y = _y;
        z = _z;
    }   
   
    Vec3f(Vec3f vec, float mag)
    {
        vec.Normalize();
        if(mag == 0)
            print("invalid vector");
        x=mag*vec.x;
        y=mag*vec.y;
        z=mag*vec.z;
    }
   
    Vec3f opAdd(const Vec3f &in oof)
    {
        return Vec3f(x + oof.x, y + oof.y, z + oof.z);
    }
   
    Vec3f opSub(const Vec3f &in oof)
    {
        return Vec3f(x - oof.x, y - oof.y, z - oof.z);
    }
   
    Vec3f opMul(const Vec3f &in oof)
    {
        return Vec3f(x * oof.x, y * oof.y, z * oof.z);
    }
   
    Vec3f opMul(const float &in oof)
    {
        return Vec3f(x * oof, y * oof, z * oof);
    }
   
    Vec3f opDiv(const Vec3f &in oof)
    {
        return Vec3f(x / oof.x, y / oof.y, z / oof.z);
    }
   
    Vec3f opDiv(const float &in oof)
    {
        return Vec3f(x / oof, y / oof, z / oof);
    }
   
   // void opAddAssign(const Vec3f &in oof)
   // {
   //     x+=oof.x;
   //     y+=oof.y;
   //     z+=oof.z;
   // }
   //
   // void opAssign(const Vec3f &in oof)
   // {
   //     x=oof.x;
   //     y=oof.y;
   //     z=oof.z;
   // }
   
    Vec3f unit()
    {
        float length = this.mag();
        if(length == 0)
            print("(uint) invalid vector");
        return Vec3f(x/length, y/length, z/length);
    }
   
    Vec3f lerp(Vec3f desired, float t)
    {
        return Vec3f((((1 - t) * this.x) + (t * desired.x)), (((1 - t) * this.y) + (t * desired.y)), (((1 - t) * this.z) + (t * desired.z)));
    }
   
    void print_self()
    {
        print("x: "+x+"; y: "+y+"; z: "+z);
    }
   
    void Normalize()
    {
        float length = this.mag();
        if(length == 0)
            print("(Normalize) invalid vector");
        x /= length;
        y /= length;
        z /= length;
    }
   
    float mag()
    {
        //print("x: "+x);
        //print("y: "+y);
        //print("z: "+z);
        float boi = Maths::Sqrt(x*x + y*y + z*z);
        //print("boi: "+boi);
        if(boi == 0) return 1;
        return boi;
    }
}

class Vec3i
{
    int x;
    int y;
    int z;
   
    Vec3i(){}
   
    Vec3i(int _x, int _y, int _z)
    {
        x = _x;
        y = _y;
        z = _z;
    }   
   
    Vec3i(Vec3i vec, int mag)
    {
        vec.Normalize();
        if(mag == 0)
            print("invalid vector");
        x=mag*vec.x;
        y=mag*vec.y;
        z=mag*vec.z;
    }
   
    Vec3i opAdd(const Vec3i &in oof)
    {
        return Vec3i(x + oof.x, y + oof.y, z + oof.z);
    }
   
    Vec3i opSub(const Vec3i &in oof)
    {
        return Vec3i(x - oof.x, y - oof.y, z - oof.z);
    }
   
    Vec3i opMul(const Vec3i &in oof)
    {
        return Vec3i(x * oof.x, y * oof.y, z * oof.z);
    }
   
    Vec3i opMul(const int &in oof)
    {
        return Vec3i(x * oof, y * oof, z * oof);
    }
   
    Vec3i opDiv(const Vec3i &in oof)
    {
        return Vec3i(x / oof.x, y / oof.y, z / oof.z);
    }
   
    Vec3i opDiv(const int &in oof)
    {
        return Vec3i(x / oof, y / oof, z / oof);
    }
   
    Vec3i unit()
    {
        int length = this.mag();
        if(length == 0)
            print("(uint) invalid vector");
        return Vec3i(x/length, y/length, z/length);
    }
   
    Vec3i lerp(Vec3i desired, int t)
    {
        return Vec3i((((1 - t) * this.x) + (t * desired.x)), (((1 - t) * this.y) + (t * desired.y)), (((1 - t) * this.z) + (t * desired.z)));
    }
   
    void print_self()
    {
        print("x: "+x+"; y: "+y+"; z: "+z);
    }
   
    void Normalize()
    {
        int length = this.mag();
        if(length == 0)
            print("(Normalize) invalid vector");
        x /= length;
        y /= length;
        z /= length;
    }
   
    int mag()
    {
        int boi = Maths::Sqrt(x*x + y*y + z*z);
        if(boi == 0) return 1;
        return boi;
    }
}