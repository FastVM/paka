module lang.test;

string rest(T)(ref T s)
{
    s = s[1 .. $];
    return s;
}

string run(string s)
{
    s.rest;
    return s;
}


void main(){
    enum x = run("x");
};
