/* e_25_6.t:    Macro arguments are pre-expanded separately.    */

#define sub( x, y)      (x - y)

/* 25.6:    */
#define head            sub(
#define body(x,y)       x,y
#define tail            )
#define head_body_tail( a, b, c)    a b c
/* "head" is once replaced to "sub(", then rescanning of "sub(" causes an
        uncompleted macro call.  Expansion of an argument should complete
        within the argument.    */
    head_body_tail( head, body(a,b), tail);

