package devsu.devops.demo.health;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@DisplayName("Health endpoints")
class HealthEndpointTest {

	@Autowired
	private MockMvc mockMvc;

	@ParameterizedTest(name = "{0} reports health without internal details")
	@ValueSource(strings = {"liveness", "readiness"})
	void probesReportUpWithoutInternalDetails(String probe) throws Exception {
		mockMvc.perform(get("/actuator/health/" + probe).accept(MediaType.APPLICATION_JSON))
				.andExpect(status().isOk())
				.andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_JSON))
				.andExpect(jsonPath("$.status").value("UP"))
				.andExpect(jsonPath("$.components").doesNotExist())
				.andExpect(jsonPath("$.details").doesNotExist());
	}

	@ParameterizedTest(name = "{0} is not exposed over HTTP")
	@ValueSource(strings = {"env", "configprops", "metrics"})
	void internalManagementEndpointsAreNotExposed(String endpoint) throws Exception {
		mockMvc.perform(get("/actuator/" + endpoint))
				.andExpect(status().isNotFound());
	}
}
