
############################################################################################

@inline function onestep_accessible_aggregation(X::Logiset{VV,W}, i_sample::Integer, w::W, r::AbstractRelation, f::AbstractFeature{V}, aggr::Aggregator, args...) where {VV,V<:VV,W<:AbstractWorld}
    vs = [X[i_sample, w2, f] for w2 in representatives(X, i_sample, w, r, f, aggr)]
    return (length(vs) == 0 ? aggregator_bottom(aggr, V) : aggr(vs))
end

@inline function onestep_accessible_aggregation(X::Logiset{VV,W}, i_sample::Integer, r::GlobalRel, f::AbstractFeature{V}, aggr::Aggregator, args...) where {VV,V<:VV,W<:AbstractWorld}
    vs = [X[i_sample, w2, f] for w2 in representatives(X, i_sample, r, f, aggr)]
    return (length(vs) == 0 ? aggregator_bottom(aggr, V) : aggr(vs))
end

############################################################################################

function onestep_accessible_aggregation(
    X::SupportedScalarLogiset{VV,W},
    i_sample::Integer,
    w::W,
    relation::AbstractRelation,
    feature::AbstractFeature{V},
    aggr::Aggregator,
    i_featsnaggr::Union{Nothing,Integer} = nothing,
    i_relation::Integer = findrelation(X, relation),
) where {VV,V<:VV,W<:AbstractWorld}
    compute_modal_gamma(support(X), fd(X), i_sample, w, relation, feature, aggregator, i_featsnaggr, i_relation)
end

@inline function onestep_accessible_aggregation(
    X::SupportedScalarLogiset{VV,W},
    i_sample::Integer,
    r::GlobalRel,
    f::AbstractFeature{V},
    aggr::Aggregator,
    args...
) where {VV,V<:VV,W<:AbstractWorld}
    compute_global_gamma(support(X), fd(X), i_sample, f, aggr, args...)
end

############################################################################################

function fwdslice_onestep_accessible_aggregation(fd::Logiset, fwdslice::FWDFeatureSlice, i_sample, r::GlobalRel, f, aggr, args...)
    # accessible_worlds = allworlds(fd, i_sample)
    accessible_worlds = representatives(fd, i_sample, r, f, aggr)
    gamma = apply_aggregator(fwdslice, accessible_worlds, aggr)
end

function fwdslice_onestep_accessible_aggregation(fd::Logiset, fwdslice::FWDFeatureSlice, i_sample, w, r::AbstractRelation, f, aggr, args...)
    # accessible_worlds = accessibles(fd, i_sample, w, r)
    accessible_worlds = representatives(fd, i_sample, w, r, f, aggr)
    gamma = apply_aggregator(fwdslice, accessible_worlds, aggr)
end

# TODO remove
# function fwdslice_onestep_accessible_aggregation(fd::SupportedScalarLogiset, fwdslice::FWDFeatureSlice, i_sample, args...)
#     fwdslice_onestep_accessible_aggregation(support(X), fd(X), fwdslice, i_sample, args...)
# end


function fwdslice_onestep_accessible_aggregation(X::SupportedScalarLogiset, fwdslice::FWDFeatureSlice, i_sample, r::GlobalRel, f, aggr, args...)
    fwdslice_onestep_accessible_aggregation(support(X), fd(X), fwdslice, i_sample, r, f, aggr, args...)
end

function fwdslice_onestep_accessible_aggregation(X::SupportedScalarLogiset, fwdslice::FWDFeatureSlice, i_sample, w, r::AbstractRelation, f, aggr, args...)
    fwdslice_onestep_accessible_aggregation(support(X), fd(X), fwdslice, i_sample, w, r, f, aggr, args...)
end

############################################################################################

function fwdslice_onestep_accessible_aggregation(
    X::OneStepFeaturedSupportingDataset{V,W},
    fd::Logiset{V,W},
    fwdslice::FWDFeatureSlice,
    i_sample::Integer,
    r::GlobalRel,
    feature::AbstractFeature,
    aggr::Aggregator,
    i_featsnaggr::Integer = find_featsnaggr_id(X, feature, aggr),
) where {V,W<:AbstractWorld}
    _fwd_gs = fwd_gs(X)
    if isnothing(_fwd_gs[i_sample, i_featsnaggr])
        gamma = fwdslice_onestep_accessible_aggregation(fd, fwdslice, i_sample, r, feature, aggr)
        _fwd_gs[i_sample, i_featsnaggr] = gamma
    end
    _fwd_gs[i_sample, i_featsnaggr]
end

function fwdslice_onestep_accessible_aggregation(
    X::OneStepFeaturedSupportingDataset{V,W},
    fd::Logiset{V,W},
    fwdslice::FWDFeatureSlice,
    i_sample::Integer,
    w::W,
    r::AbstractRelation,
    feature::AbstractFeature,
    aggr::Aggregator,
    i_featsnaggr = find_featsnaggr_id(X, feature, aggr),
    i_relation = nothing, # TODO fix
)::V where {V,W<:AbstractWorld}
    _fwd_rs = fwd_rs(X)
    if isnothing(_fwd_rs[i_sample, w, i_featsnaggr, i_relation])
        gamma = fwdslice_onestep_accessible_aggregation(fd, fwdslice, i_sample, w, r, feature, aggr)
        _fwd_rs[i_sample, w, i_featsnaggr, i_relation] = gamma
    end
    _fwd_rs[i_sample, w, i_featsnaggr, i_relation]
end

############################################################################################