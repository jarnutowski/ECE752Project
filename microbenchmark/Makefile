HIP_PATH?= /opt/rocm/hip
HIPCC=$(HIP_PATH)/bin/hipcc

export KMDUMPISA=1

micro.o: micro.cpp
	$(HIPCC) --amdgpu-target=gfx801 $(CXXFLAGS) micro.cpp -o micro.o

clean:
	rm -rf micro.o dump-gfx801.hsaco dump-gfx801.isa dump-gfx801.isabin

