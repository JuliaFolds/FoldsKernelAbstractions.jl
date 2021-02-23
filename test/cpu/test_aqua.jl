module TestAqua

import Aqua
import FoldsKernelAbstractions
using Test

Aqua.test_all(FoldsKernelAbstractions; ambiguities = false, project_extras = false)

@testset "Method ambiguity" begin
    Aqua.test_ambiguities(FoldsKernelAbstractions)
end

end  # module
