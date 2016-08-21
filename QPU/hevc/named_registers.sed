# Replace several raX, rbY register with their vc4 mnemonic. 
# Example usage: sed -f named_registers.sed [file_in] > [file_out]
#
# It is important to distinct between reading and
# writing access because the mnemonics could differ
#
# Source: 
# http://maazl.de/project/vc4asm/doc/expressions.html
#
# Reg.        read              write
# nmbr.  file A| file B     file A| file B
# 32          unif                r0  
# 33           |                  r1  
# 34           |                  r2  
# 35          vary                r3  
# 36           |                tmurs
# 37           |           r5quad | r5rep
# 38  elem_num | qpu_num       irq/interrupt
# 39              (nop register)
# 40                    unif_addr | unif_addr_rel
# 41   x_coord |y_coord   x_coord | y_coord
# 42   ms_mask |rev_flag   ms_mask| rev_flag
# 43                            stencil
# 44                            tlbz
# 45                            tlbm
# 46                            tlbc
# 47                            tlbam
# 48          vpm               vpm 
# 49    vr_busy|vw_busy   vr_setup| vw_setup
# 50    vr_wait|vw_wait   vr_addr | vw_addr
# 51      mutex/mutex_acq    mutex/mutex_rel
# 52                            recip
# 53                          recipsqrt
# 54                            exp 
# 55                            log 
# 56                            t0s 
# 57                            t0t 
# 58                            t0r 
# 59                            t0b 
# 60                            t1s 
# 61                            t1t 
# 62                            t1r 
# 63                            t1b 
#
# _UNDEFINED_ Keyword: Dummy token to mark access
# with undefined beheaviour (or without name).
# The original name will be restored with the last rule.

s/\(,\s*\)\<r[ab]32\>/\1unif/g
s/\<r[ab]32\>/r0/g

s/\(,\s*\)\<r\([ab]33\)\>/\1_UNDEFINED_\2/g
s/\<r[ab]33\>/r1/g

s/\(,\s*\)\<r\([ab]34\)\>/\1_UNDEFINED_\2/g
s/\<r[ab]34\>/r2/g

s/\(,\s*\)\<r[ab]35\>/\1vary/g
s/\<r[ab]35\>/r3/g

s/\(,\s*\)\<r\([ab]36\)\>/\1_UNDEFINED_\2/g
s/\<r[ab]36\>/tmurs/g

s/\(,\s*\)\<r\([ab]37\)\>/\1_UNDEFINED_\2/g
s/\<ra37\>/r5quad/g
s/\<rb37\>/r5rep/g

s/\(,\s*\)\<ra38\>/\1elem_num/g
s/\(,\s*\)\<rb38\>/\1qpu_num/g
s/\<r[ab]38\>/interrupt/g

s/\(,\s*\)\<r\([ab]40\)\>/\1_UNDEFINED_\2/g
s/\<ra40\>/unif_addr/g
s/\<rb40\>/unif_addr_rel/g

s/\<ra41\>/x_coord/g
s/\<rb41\>/y_coord/g

s/\<ra42\>/ms_mask/g
s/\<rb42\>/rev_flag/g

s/\(,\s*\)\<r\([ab]43\)\>/\1_UNDEFINED_\2/g
s/\<r[ab]43\>/stencil/g

s/\(,\s*\)\<r\([ab]44\)\>/\1_UNDEFINED_\2/g
s/\<r[ab]44\>/tlbz/g

s/\(,\s*\)\<r\([ab]45\)\>/\1_UNDEFINED_\2/g
s/\<r[ab]45\>/tlbm/g

s/\(,\s*\)\<r\([ab]46\)\>/\1_UNDEFINED_\2/g
s/\<r[ab]46\>/tlbc/g

s/\(,\s*\)\<r\([ab]47\)\>/\1_UNDEFINED_\2/g
s/\<r[ab]47\>/tlbam/g

s/\<r[ab]48\>/vpm/g

s/\(,\s*\)\<ra49\>/\1vr_busy/g
s/\(,\s*\)\<rb49\>/\1vw_busy/g
s/\<ra49\>/vr_setup/g
s/\<rb49\>/vw_setup/g

s/\(,\s*\)\<ra50\>/\1vr_wait/g
s/\(,\s*\)\<rb50\>/\1vw_wait/g
s/\<ra50\>/vr_addr/g
s/\<rb50\>/vw_addr/g

s/\(,\s*\)\<r[ab]51\>/\1mutex_acq/g
s/\<r[ab]51\>/mutex_rel/g

s/\(,\s*\)\<r\([ab]52\)\>/\1_UNDEFINED_\2/g
s/\<r[ab]52\>/recip/g

s/\(,\s*\)\<r\([ab]53\)\>/\1_UNDEFINED_\2/g
s/\<r[ab]53\>/recipsqrt/g

s/\(,\s*\)\<r\([ab]54\)\>/\1_UNDEFINED_\2/g
s/\<r[ab]54\>/exp/g

s/\(,\s*\)\<r\([ab]55\)\>/\1_UNDEFINED_\2/g
s/\<r[ab]55\>/log/g

s/\(,\s*\)\<r\([ab]56\)\>/\1_UNDEFINED_\2/g
s/\<r[ab]56\>/t0s/g

s/\(,\s*\)\<r\([ab]57\)\>/\1_UNDEFINED_\2/g
s/\<r[ab]57\>/t0t/g

s/\(,\s*\)\<r\([ab]58\)\>/\1_UNDEFINED_\2/g
s/\<r[ab]58\>/t0r/g

s/\(,\s*\)\<r\([ab]59\)\>/\1_UNDEFINED_\2/g
s/\<r[ab]59\>/t0b/g

s/\(,\s*\)\<r\([ab]60\)\>/\1_UNDEFINED_\2/g
s/\<r[ab]60\>/t1s/g

s/\(,\s*\)\<r\([ab]61\)\>/\1_UNDEFINED_\2/g
s/\<r[ab]61\>/t1t/g

s/\(,\s*\)\<r\([ab]62\)\>/\1_UNDEFINED_\2/g
s/\<r[ab]62\>/t1r/g

s/\(,\s*\)\<r\([ab]63\)\>/\1_UNDEFINED_\2/g
s/\<r[ab]63\>/t1b/g

s/_UNDEFINED_/r/g
