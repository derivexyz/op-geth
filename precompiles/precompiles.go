package precompiles

/*
#cgo LDFLAGS: -L../target/release/ -lprecompiles -lm

#include <stdbool.h>
#include <stdint.h>

uint64_t __precompile_black76_gas(const void* data_ptr, const uint32_t data_len);
uint8_t __precompile_black76(const void* data_ptr, const uint32_t data_len, void* ret_val, void* out_len);

*/
import "C"
import (
	"fmt"
	"unsafe"
)

type Black76 struct{}

func (a *Black76) RequiredGas(input []byte) uint64 {
	cstr := unsafe.Pointer(&input[0])
	len := C.uint(len(input))

	gas := C.__precompile_black76_gas(cstr, len)

	return uint64(gas)
}

func (a *Black76) Run(input []byte) ([]byte, error) {
	output := make([]byte, 48)
	cout := unsafe.Pointer(&output[0])

	cstr := unsafe.Pointer(&input[0])
	len := C.uint(len(input))
	out_len := C.uint(0)
	out_len_ptr := unsafe.Pointer(&out_len)

	res := C.__precompile_black76(cstr, len, cout, out_len_ptr)

	output[47] = byte(res)

	output2 := make([]byte, out_len)
	copy(output2, output[:out_len])

	var err error = nil
	if res != 0 {
		err = fmt.Errorf("error: %d", res)
	}

	return output2[:], err
}
