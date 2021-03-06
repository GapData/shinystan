library(shinystan)
context("Using shinystan objects")

sso <- eight_schools
not_sso <- sso@model_name
not_sso_msg <- "specify a shinystan object"

# load 'old_sso', a shinystan object created by previous shinystan version
load("old_sso_for_tests.rda")
old_sso_msg <- "use the 'update_sso' function to update your object"


# launch_shinystan --------------------------------------------------------
test_that("launch_shinystan throws appropriate errors", {
  expect_error(launch_shinystan(sso@summary), "not a valid input")
  expect_error(launch_shinystan(old_sso), old_sso_msg)
})


# model_name --------------------------------------------------------------
test_that("model_name works", {
  expect_error(model_name(old_sso), old_sso_msg)
  expect_error(model_name(not_sso), not_sso_msg)
  sso2 <- model_name(sso, "test_rename")
  expect_identical(model_name(sso2), "test_rename")
  expect_error(model_name(sso, 1234), "should be a single string")
  expect_error(model_name(sso, c("a", "b")), "should be a single string")
})

# model_code --------------------------------------------------------------
test_that("model_code works", {
  expect_error(model_code(old_sso), old_sso_msg)
  expect_error(model_code(not_sso), not_sso_msg)
  sso2 <- model_code(sso, "test_code")
  expect_identical(model_code(sso2), "test_code")
  expect_identical(model_code(sso2), slot(sso2, "model_code"))
  expect_error(model_code(sso, 1234), "should be NULL or a string")
})

# notes -------------------------------------------------------------------
test_that("notes works", {
  expect_error(notes(old_sso), old_sso_msg)
  expect_error(notes(not_sso), not_sso_msg)
  sso2 <- notes(sso, "test_notes_replace", replace = TRUE)
  expect_identical(slot(sso2, "user_model_info"), "test_notes_replace")
  sso2 <- notes(sso2, "test_notes_keep", replace = FALSE)
  expect_identical(slot(sso2, "user_model_info"), notes(sso2))
  expect_error(notes(sso, 1234), "should be a single string")
  expect_error(notes(sso, c("a", "b")), "should be a single string")
})


# retrieve ----------------------------------------------------------------
test_that("retrieve works", {
  expect_error(retrieve(old_sso), old_sso_msg)
  expect_error(retrieve(not_sso), not_sso_msg)
  expect_error(retrieve(not_sso, what = "mean"), not_sso_msg)
  
  stats1 <- c("median", "mean", "rhat", "ess", "sd", "mcse")
  whats <- c(stats1, "quantiles", "divergent", "treedepth", "stepsize", "accept_stat")
  for (what in whats)
    expect_equal_to_reference(
      retrieve(sso, what), 
      file = file.path("retrieve_sso_answers", paste0("test_answer_", what, ".rds"))
    )
  
  for (what in stats1)
    expect_equal(names(retrieve(sso, what, pars = c("mu", "tau"))), c("mu", "tau"))
  
  expect_equal(rownames(retrieve(sso, what = "quantiles", pars = c("mu", "theta[2]"))), 
               c("mu", "theta[2]"))
})


# generate_quantity -------------------------------------------------------
test_that("generate_quantity works", {
  expect_error(generate_quantity(old_sso), old_sso_msg)
  expect_error(generate_quantity(not_sso), not_sso_msg)
  
  sso2 <- generate_quantity(sso, fun = function(x) x^2,
                           param1 = "tau", new_name = "tau_sq")
  expect_equivalent(sso2@posterior_sample[,, "tau_sq", drop=FALSE], 
                    sso@posterior_sample[,, "tau", drop=FALSE]^2)
  
  sso2 <- generate_quantity(sso, fun = "-",
                           param1 = "theta[1]", param2 = "theta[2]",
                           new_name = "theta1minus2")
  expect_equivalent(sso2@posterior_sample[,, "theta1minus2", drop=FALSE], 
                    sso@posterior_sample[,, "theta[1]", drop=FALSE] - 
                      sso@posterior_sample[,, "theta[2]", drop=FALSE])
  
  # test when sso only has one chain
  sso3 <- as.shinystan(list(cbind(b1 = rnorm(100), b2 = rnorm(100), s = rexp(100))))
  sso3 <- generate_quantity(sso3, param1 = "b1", param2 = "b2", 
                            fun = "+", new_name = "b1plusb2")
  expect_equivalent(sso3@posterior_sample[,, "b1plusb2", drop=FALSE], 
                    sso3@posterior_sample[,, "b1", drop=FALSE] + 
                      sso3@posterior_sample[,, "b2", drop=FALSE])
})


# drop_parameters ---------------------------------------------------------
test_that("drop_parameters throws correct warnings/errors", {
  expect_error(drop_parameters(old_sso, pars = "mu"), old_sso_msg)
  expect_error(drop_parameters(not_sso, pars = "mu"), not_sso_msg)
  expect_error(drop_parameters(sso, pars = "log-posterior"), 
               "log-posterior can't be dropped")
  expect_error(drop_parameters(sso, pars = c("theta[1]", "mu")), 
               regexp = "individual elements")
  expect_error(drop_parameters(sso, pars = "omega"), regexp = "No matches")
  expect_warning(drop_parameters(sso, pars = c("mu", "omega")), 
                 regexp = "not found and ignored: omega")
})
test_that("drop_parameters works", {
  pn <- sso@param_names
  pd <- sso@param_dims
  s <- sso@summary
  samp <- sso@posterior_sample
  
  sso2 <- drop_parameters(sso, pars = "mu")
  expect_identical(sso2@param_names, pn[pn != "mu"])
  expect_identical(sso2@param_dims, pd[names(pd) != "mu"])
  expect_identical(sso2@summary, s[rownames(s) != "mu", ])
  expect_identical(sso2@posterior_sample, samp[,, dimnames(samp)[[3]] != "mu"])
  
  sso2 <- drop_parameters(sso, pars = "theta")
  expect_identical(sso2@param_names, grep("theta", pn, value = TRUE, invert = TRUE))
  expect_identical(sso2@param_dims, pd[names(pd) != "theta"])
  tmp <- s[grep("theta", rownames(s), value = TRUE, invert = TRUE), ]
  expect_identical(sso2@summary, tmp)
  tmp <- samp[,, grep("theta", dimnames(samp)[[3]], value = TRUE, invert = TRUE)]
  expect_identical(sso2@posterior_sample, tmp)
  
  sso2 <- drop_parameters(sso, pars = c("theta", "tau"))
  tmp <- grep("theta|tau", pn, value = TRUE, invert = TRUE)
  expect_identical(sso2@param_names, tmp)
  tmp <- pd[grep("theta|tau", names(pd), value = TRUE, invert = TRUE)]
  expect_identical(sso2@param_dims, tmp)
  tmp <- s[grep("theta|tau", rownames(s), value = TRUE, invert = TRUE), ]
  expect_identical(sso2@summary, tmp)
  tmp <- samp[,, grep("theta|tau", dimnames(samp)[[3]], value = TRUE, invert = TRUE)]
  expect_identical(sso2@posterior_sample, tmp)
})


# sso_info ----------------------------------------------------------------
test_that("sso_info error checking", {
  expect_error(sso_info(old_sso), old_sso_msg)
  expect_error(sso_info(sso@posterior_sample), "specify a shinystan object")
})

test_that("sso_info prints output", {
  expect_output(sso_info(sso), "sso")
  expect_output(sso_info(sso), "Model name: Demo")
  expect_output(sso_info(sso), "Parameters: 11")
  expect_output(sso_info(sso), "Chains: 4")
  expect_output(sso_info(sso), "Has model code: TRUE")
  expect_output(sso_info(sso), "Has user notes: FALSE")
})

