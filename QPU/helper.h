// Helper for printing results

/*
 * Get maximal number of required chars for list of signed numbers.
 * Flags for respect of minus sign and hex base.
 */
int max_digits(int *p_el, size_t N, int bAdd_minus_sign, int bHex){
    int m, M=0;
    while( N-- > 0 ){
        if( bHex){
            m = (p_el)?(32 - __builtin_clz(abs(*p_el))):0;
            // from bits to bytes
            m = (m-1)/4 + 1;
        }else{
            m = log10(abs(*p_el - 1)) + 1;
        }
        if( bAdd_minus_sign && *p_el < 0 ) ++m;
        if( m > M ) M = m;
        ++p_el;
    }
    return M;
}

/* Print N=16 values in a row. width argument could be evaluated with max_digits().
 * Flags for hex base and unsigned number.
 */
int print16line(unsigned int *p_el, int N, int width, int bHex, int bUnsigned){
    while( N-- > 0 ){
        if( bUnsigned && bHex ) printf("0x%*X", width, (unsigned int) *p_el++);
        if( bUnsigned && !bHex ) printf("%*u", width, (unsigned int) *p_el++);
        if( !bUnsigned && !bHex ) printf("%*i", width, (int) *p_el++);
        if( !bUnsigned && bHex ){
            int bNeg = (((int)*p_el) < 0);
            printf("%s0x%*X",
                    // bNeg?"-":"", bNeg?-(width-1):-width,
                    bNeg?"-":" ", -(width-1),
                    abs((int) *p_el++));
        }
    }
    printf("\n");
}

/* To print colunmn number over/under output of print16line().
 */
int print16headline(int N, int width, int bHex){
    int i = 0;
    while( N-- > 0 ){
        // Three extra spaces for '-' and '0x'.
        if( bHex ) printf("  %*X ", width, i);
        else printf(" %*i", width, i);
        ++i;
    }
    printf("\n");
}
