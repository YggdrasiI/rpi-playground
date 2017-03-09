Test to show effect of horizontal vector roatition ('<<', '>>')
and condition codes (.setf, .ifXX)

The QPU code takes two uniforms, (-1 and return address) and returns
two vectors. 
Both vectors will be initialized with -1 at all 16 positions and then
be updated at excact one position (from the elem_num register).

In the first vector, a rotation (by R units) and filtering (restrict update
to position P) will be done.
In the second vector, the operation ordering will be swaped to show the differences.


Notes from the VideoCore reference about vector rotations:
   • The full horizontal vector rotate is only available when both of
	   the mul ALU input arguments are taken from accumulators r0-r3.
   • The rotation can either be specified directly from the immediate data
	   or taken from accumulator r5, element 0, bits [3:0].


Notes from the VideoCore reference about condition codes:
Condition Codes

   • The QPU keeps a set of N, Z and C flag bits per 16 SIMD element.
	   These flags are updated based on the result of the ADD ALU if the ‘sf’ bit is set.
		 If the sf bit is set and the ADD ALU executes a NOP or its condition code was
     NEVER, flags are set based upon the result of the MUL ALU result.

   • The cond_add and cond_mul fields specify the following conditions:
				Never (NB gates ALU – useful for LDI instructions to save ALU power)
				Always
				ZS (zero set)
				ZC (zero clear)
				NS (negative set)
				NC (negative clear)
				CS (carry set)
				CC (carry clear)
