#include <cpp11.hpp>
#include <string>

[[cpp11::register]]
std::string ledgrcore_spike_cpp_hello() {
    return "cpp toolchain alive";
}
