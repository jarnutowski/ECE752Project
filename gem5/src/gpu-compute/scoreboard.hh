// Scoreboard header file
#ifndef __SCOREBOARD_HH__
#define __SCOREBOARD_HH__

#include <cstdint>
#include <string>
#include <vector>
#include <utility>

#include "sim/stats.hh"
#include "gpu-compute/wavefront.hh"
#include "gpu-compute/register_file.hh"

class ComputeUnit;
class Wavefront;

struct ComputeUnitParams;


class Scoreboard
{
  public: 
    Scoreboard();
    ~Scoreboard();
    bool regValid(Wavefront *w, GPU);

  private:
    
    
    std::vector<bool> vregs;
    std::vector<bool> sregs;
};

#endif // __SCOREBOARD_HH__

