
# Compute modal dataset propositions and 1-modal decisions
struct OneStepFeaturedSupportingDataset{
    V<:Number,
    W<:AbstractWorld,
    FR<:AbstractFrame{W,Bool},
    VV<:Union{V,Nothing},
    FWDRS<:AbstractRelationalSupport{VV,W,FR},
    FWDGS<:Union{AbstractGlobalSupport{V},Nothing},
    G<:AbstractVector{Tuple{<:AbstractFeature,<:Aggregator}},
} <: FeaturedSupportingDataset{V,W,FR}

    # Relational support
    fwd_rs              :: FWDRS

    # Global support
    fwd_gs              :: FWDGS

    # Features and Aggregators
    featsnaggrs         :: G

    function OneStepFeaturedSupportingDataset(
        fwd_rs::FWDRS,
        fwd_gs::FWDGS,
        featsnaggrs::G,
    ) where {
        V<:Number,
        W<:AbstractWorld,
        FR<:AbstractFrame{W,Bool},
        VV<:Union{V,Nothing},
        FWDRS<:AbstractRelationalSupport{VV,W,FR},
        FWDGS<:Union{AbstractGlobalSupport{V},Nothing},
        G<:AbstractVector{Tuple{<:AbstractFeature,<:Aggregator}},
    }
        @assert nfeatsnaggrs(fwd_rs) == length(featsnaggrs)       "Can't instantiate $(ty) with unmatching nfeatsnaggrs for fwd_rs and provided featsnaggrs: $(nfeatsnaggrs(fwd_rs)) and $(length(featsnaggrs))"
        if fwd_gs != nothing
            @assert nfeatsnaggrs(fwd_gs) == length(featsnaggrs)   "Can't instantiate $(ty) with unmatching nfeatsnaggrs for fwd_gs and provided featsnaggrs: $(nfeatsnaggrs(fwd_gs)) and $(length(featsnaggrs))"
            @assert nsamples(fwd_gs) == nsamples(fwd_rs)          "Can't instantiate $(ty) with unmatching nsamples for fwd_gs and fwd_rs support: $(nsamples(fwd_gs)) and $(nsamples(fwd_rs))"
        end
        new{V,W,FR,VV,FWDRS,FWDGS,G}(fwd_rs, fwd_gs, featsnaggrs)
    end

    _default_rs_type(::Type{<:AbstractWorld}) = GenericRelationalSupport
    _default_rs_type(::Type{<:Union{OneWorld,Interval,Interval2D}}) = UniformFullDimensionalRelationalSupport

    # A function that computes the support from an explicit modal dataset
    Base.@propagate_inbounds function OneStepFeaturedSupportingDataset(
        fd                     :: Logiset{V,W},
        relational_support_type :: Type{<:AbstractRelationalSupport} = _default_rs_type(W);
        compute_relation_glob = false,
        use_memoization = false,
    ) where {V,W<:AbstractWorld}

        # @logmsg LogOverview "Logiset -> SupportedScalarLogiset "

        _fwd = fwd(fd)
        _features = features(fd)
        _relations = relations(fd)
        _grouped_featsnaggrs =  grouped_featsnaggrs(fd)
        featsnaggrs = features_grouped_featsaggrsnops2featsnaggrs(features(fd), grouped_featsaggrsnops(fd))
    
        compute_fwd_gs = begin
            if globalrel in _relations
                throw_n_log("globalrel in relations: $(_relations)")
                _relations = filter!(l->l≠globalrel, _relations)
                true
            elseif compute_relation_glob
                true
            else
                false
            end
        end

        _n_samples = nsamples(fd)
        nrelations = length(_relations)
        nfeatsnaggrs = sum(length.(_grouped_featsnaggrs))

        # Prepare fwd_rs
        fwd_rs = relational_support_type(fd, use_memoization)

        # Prepare fwd_gs
        fwd_gs = begin
            if compute_fwd_gs
                GenericGlobalSupport(fd)
            else
                nothing
            end
        end

        # p = Progress(_n_samples, 1, "Computing EMD supports...")
        Threads.@threads for i_sample in 1:_n_samples
            # @logmsg LogDebug "Instance $(i_sample)/$(_n_samples)"

            # if i_sample == 1 || ((i_sample+1) % (floor(Int, ((_n_samples)/4))+1)) == 0
            #     @logmsg LogOverview "Instance $(i_sample)/$(_n_samples)"
            # end

            for (i_feature,aggregators) in enumerate(_grouped_featsnaggrs)
                feature = _features[i_feature]
                # @logmsg LogDebug "Feature $(i_feature)"

                fwdslice = fwdread_channel(_fwd, i_sample, i_feature)

                # @logmsg LogDebug fwdslice

                # Global relation (independent of the current world)
                if compute_fwd_gs
                    # @logmsg LogDebug "globalrel"

                    # TODO optimize: all aggregators are likely reading the same raw values.
                    for (i_featsnaggr,aggr) in aggregators
                    # Threads.@threads for (i_featsnaggr,aggr) in aggregators
                        
                        gamma = fwdslice_onestep_accessible_aggregation(fd, fwdslice, i_sample, globalrel, feature, aggr)

                        # @logmsg LogDebug "Aggregator[$(i_featsnaggr)]=$(aggr)  -->  $(gamma)"

                        fwd_gs[i_sample, i_featsnaggr] = gamma
                    end
                end

                if !use_memoization
                    # Other relations
                    for (i_relation,relation) in enumerate(_relations)

                        # @logmsg LogDebug "Relation $(i_relation)/$(nrelations)"

                        for (i_featsnaggr,aggr) in aggregators
                            fwd_rs_init_world_slice(fwd_rs, i_sample, i_featsnaggr, i_relation)
                        end

                        for w in allworlds(fd, i_sample)

                            # @logmsg LogDebug "World" w

                            # TODO optimize: all aggregators are likely reading the same raw values.
                            for (i_featsnaggr,aggr) in aggregators
                                
                                gamma = fwdslice_onestep_accessible_aggregation(fd, fwdslice, i_sample, w, relation, feature, aggr)

                                # @logmsg LogDebug "Aggregator" aggr gamma

                                fwd_rs[i_sample, w, i_featsnaggr, i_relation] = gamma
                            end
                        end
                    end
                end
            end
            # next!(p)
        end
        OneStepFeaturedSupportingDataset(fwd_rs, fwd_gs, featsnaggrs)
    end
end

fwd_rs(X::OneStepFeaturedSupportingDataset) = X.fwd_rs
fwd_gs(X::OneStepFeaturedSupportingDataset) = X.fwd_gs
featsnaggrs(X::OneStepFeaturedSupportingDataset) = X.featsnaggrs

nsamples(X::OneStepFeaturedSupportingDataset) = nsamples(fwd_rs(X))
# nfeatsnaggrs(X::OneStepFeaturedSupportingDataset) = nfeatsnaggrs(fwd_rs(X))

# TODO delegate to the two components...
function checksupportconsistency(
    fd::Logiset{V,W},
    X::OneStepFeaturedSupportingDataset{V,W},
) where {V,W<:AbstractWorld}
    @assert nsamples(fd) == nsamples(X)                "Consistency check failed! Unmatching nsamples for fd and support: $(nsamples(fd)) and $(nsamples(X))"
    # @assert nrelations(fd) == (nrelations(fwd_rs(X)) + (isnothing(fwd_gs(X)) ? 0 : 1))            "Consistency check failed! Unmatching nrelations for fd and support: $(nrelations(fd)) and $(nrelations(fwd_rs(X)))+$((isnothing(fwd_gs(X)) ? 0 : 1))"
    @assert nrelations(fd) >= nrelations(fwd_rs(X))            "Consistency check failed! Inconsistent nrelations for fd and support: $(nrelations(fd)) < $(nrelations(fwd_rs(X)))"
    _nfeatsnaggrs = nfeatsnaggrs(fd)
    @assert _nfeatsnaggrs == length(featsnaggrs(X))  "Consistency check failed! Unmatching featsnaggrs for fd and support: $(featsnaggrs(fd)) and $(featsnaggrs(X))"
    return true
end

usesmemo(X::OneStepFeaturedSupportingDataset) = usesglobalmemo(X) || usesmodalmemo(X)
usesglobalmemo(X::OneStepFeaturedSupportingDataset) = false
usesmodalmemo(X::OneStepFeaturedSupportingDataset) = usesmemo(fwd_rs(X))

Base.size(X::OneStepFeaturedSupportingDataset) = (size(fwd_rs(X)), (isnothing(fwd_gs(X)) ? () : size(fwd_gs(X))))

find_featsnaggr_id(X::OneStepFeaturedSupportingDataset, feature::AbstractFeature, aggregator::Aggregator) = findfirst(x->x==(feature, aggregator), featsnaggrs(X))

function _slice_dataset(X::OneStepFeaturedSupportingDataset, inds::AbstractVector{<:Integer}, args...; kwargs...)
    OneStepFeaturedSupportingDataset(
        _slice_dataset(fwd_rs(X), inds, args...; kwargs...),
        (isnothing(fwd_gs(X)) ? nothing : _slice_dataset(fwd_gs(X), inds, args...; kwargs...)),
        featsnaggrs(X)
    )
end


function hasnans(X::OneStepFeaturedSupportingDataset)
    hasnans(fwd_rs(X)) || (!isnothing(fwd_gs(X)) && hasnans(fwd_gs(X)))
end

isminifiable(X::OneStepFeaturedSupportingDataset) = isminifiable(fwd_rs(X)) && (isnothing(fwd_gs(X)) || isminifiable(fwd_gs(X)))

function minify(X::OSSD) where {OSSD<:OneStepFeaturedSupportingDataset}
    (new_fwd_rs, new_fwd_gs), backmap =
        minify([
            fwd_rs(X),
            fwd_gs(X),
        ])

    X = OSSD(
        new_fwd_rs,
        new_fwd_gs,
        featsnaggrs(X),
    )
    X, backmap
end

function displaystructure(X::OneStepFeaturedSupportingDataset; indent_str = "")
    out = "$(typeof(X))\t$((Base.summarysize(X)) / 1024 / 1024 |> x->round(x, digits=2)) MBs\n"
    out *= indent_str * "├ fwd_rs\t$(Base.summarysize(fwd_rs(X)) / 1024 / 1024 |> x->round(x, digits=2)) MBs\t"
    if usesmodalmemo(X)
        out *= "(shape $(Base.size(fwd_rs(X))), $(nmemoizedvalues(fwd_rs(X))) values," *
            " $(round(nonnothingshare(fwd_rs(X))*100, digits=2))% memoized)\n"
    else
        out *= "(shape $(Base.size(fwd_rs(X))))\n"
    end
    out *= indent_str * "└ fwd_gs\t"
    if !isnothing(fwd_gs(X))
        out *= "$(Base.summarysize(fwd_gs(X)) / 1024 / 1024 |> x->round(x, digits=2)) MBs\t"
        if usesglobalmemo(X)
            out *= "(shape $(Base.size(fwd_gs(X))), $(nmemoizedvalues(fwd_gs(X))) values," *
                " $(round(nonnothingshare(fwd_gs(X))*100, digits=2))% memoized)\n"
        else
            out *= "(shape $(Base.size(fwd_gs(X))))\n"
        end
    else
        out *= "−"
    end
    out
end


############################################################################################

function compute_global_gamma(
    X::OneStepFeaturedSupportingDataset{V,W},
    fd::Logiset{V,W},
    i_sample::Integer,
    feature::AbstractFeature,
    aggregator::Aggregator,
    i_featsnaggr::Integer = find_featsnaggr_id(X, feature, aggregator),
) where {V,W<:AbstractWorld}
    _fwd_gs = fwd_gs(X)
    # @assert !isnothing(_fwd_gs) "Error. SupportedScalarLogiset must be built with compute_relation_glob = true for it to be ready to test global decisions."
    if usesglobalmemo(X) && isnothing(_fwd_gs[i_sample, i_featsnaggr])
        error("TODO finish this: memoization on the global table")
        # gamma = TODO...
        # i_feature = findfeature(fd, feature)
        # fwdslice = fwdread_channel(fwd(fd), i_sample, i_feature)
        _fwd_gs[i_sample, i_featsnaggr] = gamma
    end
    _fwd_gs[i_sample, i_featsnaggr]
end

function compute_modal_gamma(
    X::OneStepFeaturedSupportingDataset{V,W},
    fd::Logiset{V,W},
    i_sample::Integer,
    w::W,
    r::AbstractRelation,
    feature::AbstractFeature,
    aggregator::Aggregator,
    i_featsnaggr = find_featsnaggr_id(X, feature, aggregator),
    i_relation = nothing,
)::V where {V,W<:AbstractWorld}
    _fwd_rs = fwd_rs(X)
    if usesmodalmemo(X) && isnothing(_fwd_rs[i_sample, w, i_featsnaggr, i_relation])
        i_feature = findfeature(fd, feature)
        fwdslice = fwdread_channel(fwd(fd), i_sample, i_feature)
        gamma = fwdslice_onestep_accessible_aggregation(fd, fwdslice, i_sample, w, r, feature, aggregator)
        fwd_rs[i_sample, w, i_featsnaggr, i_relation, gamma]
    end
    _fwd_rs[i_sample, w, i_featsnaggr, i_relation]
end