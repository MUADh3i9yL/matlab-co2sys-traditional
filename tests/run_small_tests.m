import matlab.unittest.TestSuite

glodap_test_1 = TestSuite.fromMethod(?GlodapTests,"compare_glodap_subset");
grid_tests = TestSuite.fromClass(?GridTests);
random_tests = TestSuite.fromClass(?RandomTests);

fullSuite = [glodap_test_1,grid_tests,random_tests];
result = run(fullSuite);