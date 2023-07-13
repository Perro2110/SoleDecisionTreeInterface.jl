using SoleData: slicedataset
import SoleData: get_instance, ninstances, nvariables, channel_size, max_channel_size, dimensionality, eltype
using SoleData: AbstractDimensionalDataset,
                AbstractDimensionalInstance,
                AbstractDimensionalChannel,
                UniformDimensionalDataset,
                DimensionalInstance,
                DimensionalChannel

using SoleLogics: TruthValue

# A modal dataset can be *active* or *passive*.
# 
# A passive modal dataset is one that you can interpret decisions on, but cannot necessarily
#  enumerate decisions for, as it doesn't have objects for storing the logic (relations, features, etc.).
# Dimensional datasets are passive.

struct PassiveDimensionalDataset{
    N,
    W<:AbstractWorld,
    DOM<:AbstractDimensionalDataset,
    FR<:AbstractDimensionalFrame{N,W},
} <: AbstractConditionalDataset{W,AbstractCondition,Bool,FR} # TODO remove AbstractCondition. Note: truth value could by different
    
    d::DOM

    function PassiveDimensionalDataset{N,W,DOM,FR}(
        d::DOM,
    ) where {N,W<:AbstractWorld,DOM<:AbstractDimensionalDataset,FR<:AbstractDimensionalFrame{N,W}}
        ty = "PassiveDimensionalDataset{$(N),$(W),$(DOM),$(FR)}"
        @assert N == dimensionality(d) "ERROR! Dimensionality mismatch: can't instantiate $(ty) with underlying structure $(DOM). $(N) == $(dimensionality(d)) should hold."
        @assert SoleLogics.goeswithdim(W, N) "ERROR! Dimensionality mismatch: can't interpret worldtype $(W) on PassiveDimensionalDataset of dimensionality = $(N)"
        new{N,W,DOM,FR}(d)
    end
    
    function PassiveDimensionalDataset{N,W,DOM}(
        d::DOM,
    ) where {N,W<:AbstractWorld,DOM<:AbstractDimensionalDataset}
        FR = typeof(_frame(d))
        _W = worldtype(FR)
        @assert W <: _W "This should hold: $(W) <: $(_W)"
        PassiveDimensionalDataset{N,_W,DOM,FR}(d)
    end

    function PassiveDimensionalDataset{N,W}(
        d::DOM,
    ) where {N,W<:AbstractWorld,DOM<:AbstractDimensionalDataset}
        PassiveDimensionalDataset{N,W,DOM}(d)
    end

    function PassiveDimensionalDataset(
        d::AbstractDimensionalDataset,
        # worldtype::Type{<:AbstractWorld},
    )
        W = worldtype(_frame(d))
        PassiveDimensionalDataset{dimensionality(d),W}(d)
    end
end

@inline function Base.getindex(
    X::PassiveDimensionalDataset{N,W},
    i_instance::Integer,
    w::W,
    f::AbstractFeature{U},
    args...,
) where {N,W<:AbstractWorld,U}
    w_values = interpret_world(w, get_instance(X.d, i_instance))
    computefeature(f, w_values)::U
end

Base.size(X::PassiveDimensionalDataset)                 = Base.size(X.d)

nvariables(X::PassiveDimensionalDataset)               = nvariables(X.d)
ninstances(X::PassiveDimensionalDataset)                  = ninstances(X.d)
channel_size(X::PassiveDimensionalDataset)              = channel_size(X.d)
max_channel_size(X::PassiveDimensionalDataset)          = max_channel_size(X.d)
dimensionality(X::PassiveDimensionalDataset)            = dimensionality(X.d)
eltype(X::PassiveDimensionalDataset)                    = eltype(X.d)

get_instance(X::PassiveDimensionalDataset, args...)     = get_instance(X.d, args...)

instances(X::PassiveDimensionalDataset{N,W}, inds::AbstractVector{<:Integer}, return_view::Union{Val{true},Val{false}} = Val(false)) where {N,W} =
    PassiveDimensionalDataset{N,W}(instances(X.d, inds, return_view))

hasnans(X::PassiveDimensionalDataset) = hasnans(X.d)

worldtype(X::PassiveDimensionalDataset{N,W}) where {N,W} = W

frame(X::PassiveDimensionalDataset, i_instance) = _frame(X.d, i_instance)

############################################################################################

_frame(X::Union{UniformDimensionalDataset,AbstractArray}, i_instance) = _frame(X)
_frame(X::Union{UniformDimensionalDataset,AbstractArray}) = FullDimensionalFrame(channel_size(X))