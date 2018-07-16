#include <iostream>
#include <fstream>
#include <vector>

float gpu_nmfa(int N, float *J, std::vector<float> betas, int num_samples, int *samples, float noise, float recombination, uint32_t seed);
int get_N();

int main(int argc, char **argv)
{
    if (argc < 2) {
        std::cerr << "Usage: " << argv[0] << " input-file" << std::endl;
        return 1;
    }
    std::ifstream input(argv[1]);
    size_t x, y;
    input >> x >> y;
    if (x != get_N() || y != get_N()) {
        std::cerr  << "Jij matrix width and height shall be " << get_N() << "." << std::endl;
        std::cerr  << "This value is determined in compile time. Check your Makefile." << std::endl;
        return 1;
    }
    std::vector<float> J;
    J.reserve(x * y);
    for (size_t i = 0; i < x * y; i++) {
        float t;
        input >> t;
        J.push_back(t);
    }
    std::vector<float> betas;
    for (size_t i = 0; i < 20; i++) betas.push_back(0.2);
    for (size_t i = 0; i < 20; i++) betas.push_back(0.4);
    for (size_t i = 0; i < 20; i++) betas.push_back(0.6);
    for (size_t i = 0; i < 20; i++) betas.push_back(0.8);
    for (size_t i = 0; i < 20; i++) betas.push_back(1.0);
    for (size_t i = 0; i < 20; i++) betas.push_back(1.2);
    for (size_t i = 0; i < 20; i++) betas.push_back(1.4);
    for (size_t i = 0; i < 20; i++) betas.push_back(1.6);
    for (size_t i = 0; i < 20; i++) betas.push_back(1.8);
    for (size_t i = 0; i < 20; i++) betas.push_back(2.0);
    for (size_t i = 0; i < 20; i++) betas.push_back(2.2);
    for (size_t i = 0; i < 20; i++) betas.push_back(2.4);
    for (size_t i = 0; i < 20; i++) betas.push_back(2.6);
    int num_samples = 100;
    std::vector<int> samples(x * num_samples, 0);
    float noise = 0.2;
    float recombination = 0.4;
    uint32_t seed = 12345;
    std::cerr << "Start gpu_nmfa" << std::endl;
    float elapsed = gpu_nmfa(static_cast<int>(x), J.data(), betas, num_samples, samples.data(), noise, recombination, seed);
    std::cerr << "Finished gpu_nmfa in " << elapsed << " ms." << std::endl;
    std::cout << "[";
    for (int i = 0; i < num_samples; i++) {
        std::cout << "[" << samples[i*x];
        for (int j = 1; j < x; j++) {
            std::cout << "," << samples[i*x + j];
        }
        std::cout << "]";
        if (i < num_samples - 1) std::cout << ",";
        else std::cout << "]" << std::endl;
    }
}
