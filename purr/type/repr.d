module purr.type.repr;

class Type 
{
    bool matches(Type other)
    {
        assert(false);
    }
}

class Number
{
    bool matches(Type other)
    {
        return null !is cast(Number) other; 
    }
}