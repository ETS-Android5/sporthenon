package com.sporthenon.updater.window;

import java.awt.BorderLayout;
import java.awt.Color;
import java.awt.Dimension;
import java.awt.FlowLayout;
import java.awt.event.ActionEvent;
import java.awt.event.ActionListener;
import java.io.StringWriter;
import java.net.HttpURLConnection;
import java.net.URL;
import java.util.LinkedList;
import java.util.List;

import javax.swing.BorderFactory;
import javax.swing.JCheckBox;
import javax.swing.JDialog;
import javax.swing.JFrame;
import javax.swing.JLabel;
import javax.swing.JPanel;
import javax.swing.JScrollPane;
import javax.swing.JTextArea;
import javax.swing.JTextField;

import org.apache.commons.io.IOUtils;
import org.apache.log4j.Logger;
import org.jsoup.Jsoup;
import org.jsoup.nodes.Document;
import org.jsoup.nodes.Element;

import com.sporthenon.db.DatabaseHelper;
import com.sporthenon.db.entity.Athlete;
import com.sporthenon.db.entity.Championship;
import com.sporthenon.db.entity.City;
import com.sporthenon.db.entity.Complex;
import com.sporthenon.db.entity.Country;
import com.sporthenon.db.entity.Event;
import com.sporthenon.db.entity.Olympics;
import com.sporthenon.db.entity.Sport;
import com.sporthenon.db.entity.State;
import com.sporthenon.db.entity.Team;
import com.sporthenon.updater.component.JCustomButton;
import com.sporthenon.updater.component.JDialogButtonBar;
import com.sporthenon.utils.StringUtils;

public class JUrlUpdateDialog extends JDialog implements ActionListener {

	private static final long serialVersionUID = 1L;

	private JTextArea jResult = null;
	private JTextField jRange = null;
	private JCheckBox[] jEntity = null;
	private JLabel jStatus = null;
	
	public JUrlUpdateDialog(JFrame owner) {
		super(owner);
		initialize();
	}

	private void initialize() {
		JPanel jContentPane = new JPanel();
		this.setDefaultCloseOperation(JDialog.DISPOSE_ON_CLOSE);
		this.setPreferredSize(new Dimension(700, 550));
		this.setSize(this.getPreferredSize());
		this.setModal(false);
		this.setLocationRelativeTo(null);
		this.setResizable(true);
		this.setTitle("URL Update");
		this.setContentPane(jContentPane);

		BorderLayout layout = new BorderLayout();
		layout.setVgap(5);
		JDialogButtonBar jButtonBar = new JDialogButtonBar(this);
		jButtonBar.getCancel().setVisible(false);
		jContentPane.setBorder(BorderFactory.createLineBorder(new Color(0, 0, 0, 0), 2));
		jContentPane.setLayout(layout);
		jContentPane.add(getButtonPanel(), BorderLayout.NORTH);
		jResult = new JTextArea();
		JScrollPane jScrollPane = new JScrollPane(jResult);
		jContentPane.add(jScrollPane, BorderLayout.CENTER);
	}

	private JPanel getButtonPanel() {
		JPanel p = new JPanel(new FlowLayout(FlowLayout.LEFT));
		p.setBorder(BorderFactory.createEtchedBorder());
		p.setPreferredSize(new Dimension(0, 70));
		
		jEntity = new JCheckBox[10];
		jEntity[0] = new JCheckBox("Athlete");
		jEntity[1] = new JCheckBox("Championship");
		jEntity[2] = new JCheckBox("City");
		jEntity[3] = new JCheckBox("Complex");
		jEntity[4] = new JCheckBox("Country");
		jEntity[5] = new JCheckBox("Event");
		jEntity[6] = new JCheckBox("Olympics");
		jEntity[7] = new JCheckBox("Sport");
		jEntity[8] = new JCheckBox("State");
		jEntity[9] = new JCheckBox("Team");
		for (JCheckBox cb : jEntity) {
			cb.setSelected(false);
			p.add(cb);
		}
		
		p.add(new JLabel("Range:"));
		jRange = new JTextField();
		jRange.setText("1-100");
		jRange.setPreferredSize(new Dimension(100, 20));
		p.add(jRange);
		
		JCustomButton jExecuteButton = new JCustomButton("Execute", "ok.png", null);
		jExecuteButton.setActionCommand("execute");
		jExecuteButton.addActionListener(this);
		p.add(jExecuteButton);
		JCustomButton jCloseButton = new JCustomButton("Close", "cancel.png", null);
		jCloseButton.setActionCommand("close");
		jCloseButton.addActionListener(this);
		p.add(jCloseButton);
		
		jStatus = new JLabel();
		p.add(jStatus);

		return p;
	}

	public void open() {
		jResult.setText("");
		this.setVisible(true);
	}

	public void actionPerformed(ActionEvent e) {
		String cmd = e.getActionCommand();
		if (cmd.equalsIgnoreCase("execute")) {
			jResult.setText("");
			new Thread (new Runnable() {
				public void run() {
					jStatus.setText("In progress...");
					executeUpdate();
					jStatus.setText("Finished.");
				}
			}).start();
		}
		else if (cmd.equalsIgnoreCase("close"))
			this.setVisible(false);
	}
	
	private void executeUpdate() {
		try {
			String proxyAddr = JMainFrame.getOptionsDialog().getProxyAddr().getText();
			String proxyPort = JMainFrame.getOptionsDialog().getProxyPort().getText();
			if (StringUtils.notEmpty(proxyAddr)) {
				System.getProperties().setProperty("http.proxyHost", proxyAddr);
				System.getProperties().setProperty("http.proxyPort", proxyPort);
			}
			
			StringBuffer sbUpdateSql = new StringBuffer();
			List<String> lMsg = new LinkedList<String>();
			List<String> lHql = new LinkedList<String>();
			String filter = " and id between " + jRange.getText().replaceAll("\\-", " and ");
			lMsg.add("Athletes (Wiki)"); lHql.add("from Athlete where urlWiki is null" + filter + " order by id");
			lMsg.add("Athletes (Oly)"); lHql.add("from Athlete where urlOlyref is null" + filter + " order by id");
			lMsg.add("Athletes (Bkt)"); lHql.add("from Athlete where urlBktref is null" + filter + " order by id");
			lMsg.add("Athletes (Bb)"); lHql.add("from Athlete where urlBbref is null" + filter + " order by id");
			lMsg.add("Athletes (Ft)"); lHql.add("from Athlete where urlFtref is null" + filter + " order by id");
			lMsg.add("Athletes (Hk)"); lHql.add("from Athlete where urlHkref is null" + filter + " order by id");
			lMsg.add("Championships (Wiki)"); lHql.add("from Championship where urlWiki is null" + filter + " order by id");
			lMsg.add("Cities (Wiki)"); lHql.add("from City where urlWiki is null" + filter + " order by id");
			lMsg.add("Complexes (Wiki)"); lHql.add("from Complex where urlWiki is null" + filter + " order by id");
			lMsg.add("Countries (Wiki)"); lHql.add("from Country where urlWiki is null" + filter + " order by id");
			lMsg.add("Countries (Oly)"); lHql.add("from Country where urlOlyref is null" + filter + " order by id");
			lMsg.add("Events (Wiki)"); lHql.add("from Event where urlWiki is null" + filter + " order by id");
			lMsg.add("Olympics (Wiki)"); lHql.add("from Olympics where urlWiki is null" + filter + " order by id");
			lMsg.add("Olympics (Oly)"); lHql.add("from Olympics where urlOlyref is null" + filter + " order by id");
			lMsg.add("Sports (Wiki)"); lHql.add("from Sport where urlWiki is null" + filter + " order by id");
			lMsg.add("Sports (Oly)"); lHql.add("from Sport where urlOlyref is null" + filter + " order by id");
			lMsg.add("States (Wiki)"); lHql.add("from State where urlWiki is null" + filter + " order by id");
			lMsg.add("Teams (Wiki)"); lHql.add("from Team where urlWiki is null" + filter + " order by id");
			lMsg.add("Teams (Bkt)"); lHql.add("from Team where urlBktref is null" + filter + " order by id");
			lMsg.add("Teams (Bb)"); lHql.add("from Team where urlBbref is null" + filter + " order by id");
			lMsg.add("Teams (Ft)"); lHql.add("from Team where urlFtref is null" + filter + " order by id");
			lMsg.add("Teams (Hk)"); lHql.add("from Team where urlHkref is null" + filter + " order by id");
			int i = 0;
			for (String hql : lHql) {
				String msg = lMsg.get(i++);
				if ((msg.matches("^Athletes.*") && !jEntity[0].isSelected()) || (msg.matches("^Championships.*") && !jEntity[1].isSelected()) || (msg.matches("^Cities.*") && !jEntity[2].isSelected()) || (msg.matches("^Complexes.*") && !jEntity[3].isSelected()) || (msg.matches("^Countries.*") && !jEntity[4].isSelected()) || (msg.matches("^Events.*") && !jEntity[5].isSelected()) || (msg.matches("^Olympics.*") && !jEntity[6].isSelected()) || (msg.matches("^Sports.*") && !jEntity[7].isSelected()) || (msg.matches("^States.*") && !jEntity[8].isSelected()) || (msg.matches("^Teams.*") && !jEntity[9].isSelected()))
					continue;
				jResult.setText(jResult.getText() + "\r\n- " + msg + "\r\n\r\n");
				List<Object> l = DatabaseHelper.execute(hql);
				for (Object o : l) {
					sbUpdateSql.append(getUrlUpdate(o, msg));
//					if (n > MAX)
//						break;
				}
			}
			DatabaseHelper.executeUpdate(sbUpdateSql.toString());
		}
		catch (Exception e_) {
			Logger.getLogger("sh").error(e_.getMessage(), e_);
		}
	}

	private String getUrlUpdate(Object o, String msg) throws Exception {
		String sql = "";
		String str1 = "", str2 = "", str3 = "", table = "";
		if (o instanceof Athlete) {
			Athlete a = (Athlete) o;
			str1 = a.getFirstName() + " " + a.getLastName();
			str2 = a.getLastName();
			str3 = a.getSport().getWikiPattern();
			table = "\"PERSON\"";
		}
		else if (o instanceof Championship) {
			Championship c = (Championship) o;
			str1 = c.getLabel();
			table = "\"CHAMPIONSHIP\"";
		}
		else if (o instanceof City) {
			City c = (City) o;
			str1 = c.getLabel();
			str2 = c.getCountry().getLabel();
			table = "\"CITY\"";
		}
		else if (o instanceof Complex) {
			Complex c = (Complex) o;
			str1 = c.getLabel();
			table = "\"COMPLEX\"";
		}
		else if (o instanceof Country) {
			Country c = (Country) o;
			str1 = c.getLabel();
			str2 = c.getCode();
			table = "\"COUNTRY\"";
		}
		else if (o instanceof Event) {
			Event e = (Event) o;
			str1 = e.getLabel();
			table = "\"EVENT\"";
		}
		else if (o instanceof Olympics) {
			Olympics o_ = (Olympics) o;
			str1 = o_.getYear().getLabel() + " " + (o_.getType() == 0 ? "Winter" : "Summer") + " Olympics";
			str2 = (o_.getType() == 0 ? "Winter" : "Summer") + "/" + o_.getYear().getLabel() + "/";
			table = "\"OLYMPICS\"";
		}
		else if (o instanceof Sport) {
			Sport s = (Sport) o;
			str1 = s.getLabel();
			table = "\"SPORT\"";
		}
		else if (o instanceof State) {
			State s = (State) o;
			str1 = s.getLabel();
			table = "\"STATE\"";
		}
		else if (o instanceof Team) {
			Team t = (Team) o;
			str1 = t.getLabel();
			table = "\"TEAM\"";
		}
		Integer id = (Integer) o.getClass().getMethod("getId").invoke(o);
		String url = null;
		URL url_ = null;
		HttpURLConnection conn = null;
		// WIKIPEDIA
		if (msg.matches(".*\\(Wiki\\)$")) {
			url = "http://en.wikipedia.org/wiki/" + str1.replaceAll("\\s", "_").replaceAll("'", "%27");
			url_ = new URL(url + "_(disambiguation)");
			conn = (HttpURLConnection) url_.openConnection();
			conn.setDoOutput(true);
			if (conn.getResponseCode() == 200) {
				StringWriter writer = new StringWriter();
				IOUtils.copy(conn.getInputStream(), writer, "UTF-8");
				Document doc = Jsoup.parse(writer.toString());
				for (Element e : doc.getElementsByTag("a")) {
					if (e.attr("href") != null && e.attr("href").matches("^/wiki/.*")) {
						Element parent = e.parent();
						if (parent != null && parent.tagName().equalsIgnoreCase("b"))
							parent = parent.parent();
						boolean b = false;
						b |= (o instanceof Athlete && parent != null && parent.text().matches(".*(" + str3 + ").*"));
						b |= (o instanceof City && parent != null && parent.text().matches(".*(city|town|capital).*"));
						b |= (o instanceof Complex && parent != null && parent.text().matches(".*(stadium|arena|venue).*"));
						b |= (o instanceof Country && parent != null && parent.text().matches(".*(country).*"));
						b |= (o instanceof Sport && parent != null && parent.text().matches(".*(sport).*"));
						b |= (o instanceof State && parent != null && parent.text().matches(".*(state).*"));
						b |= (o instanceof Team && parent != null && parent.text().matches(".*(team).*"));
						if (b) {
							sql += "UPDATE " + table + " SET url_wiki='" + url.replaceAll("/wiki.+$", e.attr("href")) + "' WHERE id=" + id + ";\r\n";
							break;				
						}
					}
				}
			}
			else {
				url_ = new URL(url);
				conn = (HttpURLConnection) url_.openConnection();
				conn.setDoOutput(true);
				if (conn.getResponseCode() == 200)
					sql += "UPDATE " + table + " SET url_wiki='" + url + "' WHERE id=" + id + ";\r\n";
			}
		}
		// OLYMPICS-REFERENCE
		if (msg.matches(".*\\(Oly\\)$")) {
			url = null;
			if (o instanceof Athlete) {
				url = "http://www.sports-reference.com/olympics/athletes/" + str2.substring(0, 2).toLowerCase() + "/" + str1.replaceAll("\\s", "-").toLowerCase() + "-1.html";	
			}
			else if (o instanceof Country) {
				url = "http://www.sports-reference.com/olympics/countries/" + str2;
			}
			else if (o instanceof Olympics) {
				url = "http://www.sports-reference.com/olympics/" + str2;
			}
			if (url != null) {
				url_ = new URL(StringUtils.normalize(url));
				conn = (HttpURLConnection) url_.openConnection();
				conn.setDoOutput(true);
				if (conn.getResponseCode() == 200) {
					StringWriter writer = new StringWriter();
					IOUtils.copy(conn.getInputStream(), writer, "UTF-8");
					if (writer.toString().indexOf("File Not Found") == -1 && writer.toString().indexOf("0 hits") == -1)
						sql += "UPDATE " + table + " SET url_olyref='" + StringUtils.normalize(url) + "' WHERE id=" + id + ";\r\n";
				}
			}
		}
		// BASKETBALL-REFERENCE
		if (msg.matches(".*\\(Bkt\\)$")) {
			url = null;
			if (o instanceof Athlete && ((Athlete)o).getSport().getId() == 24) {
				url = "http://www.basketball-reference.com/players/" + str2.substring(0, 1).toLowerCase() + "/" + str2.substring(0, str2.length() > 5 ? 5 : str2.length()).toLowerCase() + str1.substring(0, 2).toLowerCase() + "01.html";	
			}
			if (url != null) {
				url_ = new URL(StringUtils.normalize(url));
				conn = (HttpURLConnection) url_.openConnection();
				conn.setDoOutput(true);
				if (conn.getResponseCode() == 200) {
					StringWriter writer = new StringWriter();
					IOUtils.copy(conn.getInputStream(), writer, "UTF-8");
					if (writer.toString().indexOf("File Not Found") == -1)
						sql += "UPDATE " + table + " SET url_bktref='" + StringUtils.normalize(url) + "' WHERE id=" + id + ";\r\n";
				}
			}
		}
		// BASEBALL-REFERENCE
		if (msg.matches(".*\\(Bb\\)$")) {
			url = null;
			if (o instanceof Athlete && ((Athlete)o).getSport().getId() == 26) {
				url = "http://www.baseball-reference.com/players/" + str2.substring(0, 1).toLowerCase() + "/" + str2.substring(0, str2.length() > 5 ? 5 : str2.length()).toLowerCase() + str1.substring(0, 2).toLowerCase() + "01.shtml";	
			}
			if (url != null) {
				url_ = new URL(StringUtils.normalize(url));
				conn = (HttpURLConnection) url_.openConnection();
				conn.setDoOutput(true);
				if (conn.getResponseCode() == 200) {
					StringWriter writer = new StringWriter();
					IOUtils.copy(conn.getInputStream(), writer, "UTF-8");
					if (writer.toString().indexOf("File Not Found") == -1)
						sql += "UPDATE " + table + " SET url_bbref='" + StringUtils.normalize(url) + "' WHERE id=" + id + ";\r\n";
				}
			}
		}
		// PRO-FOOTBALL-REFERENCE
		if (msg.matches(".*\\(Ft\\)$")) {
			url = null;
			if (o instanceof Athlete && ((Athlete)o).getSport().getId() == 23) {
				url = "http://www.pro-football-reference.com/players/" + str2.substring(0, 1) + "/" + str2.substring(0, str2.length() > 4 ? 4 : str2.length()) + str1.substring(0, 2) + "00.htm";	
			}
			if (url != null) {
				url_ = new URL(StringUtils.normalize(url));
				conn = (HttpURLConnection) url_.openConnection();
				conn.setDoOutput(true);
				if (conn.getResponseCode() == 200) {
					StringWriter writer = new StringWriter();
					IOUtils.copy(conn.getInputStream(), writer, "UTF-8");
					if (writer.toString().indexOf("File Not Found") == -1)
						sql += "UPDATE " + table + " SET url_ftref='" + StringUtils.normalize(url) + "' WHERE id=" + id + ";\r\n";
				}
			}
		}
		// HOCKEY-REFERENCE
		if (msg.matches(".*\\(Hk\\)$")) {
			url = null;
			if (o instanceof Athlete && ((Athlete)o).getSport().getId() == 25) {
				url = "http://www.hockey-reference.com/players/" + str2.substring(0, 1).toLowerCase() + "/" + str2.substring(0, str2.length() > 5 ? 5 : str2.length()).toLowerCase() + str1.substring(0, 2).toLowerCase() + "01.html";	
			}
			if (url != null) {
				url_ = new URL(StringUtils.normalize(url));
				conn = (HttpURLConnection) url_.openConnection();
				conn.setDoOutput(true);
				if (conn.getResponseCode() == 200) {
					StringWriter writer = new StringWriter();
					IOUtils.copy(conn.getInputStream(), writer, "UTF-8");
					if (writer.toString().indexOf("File Not Found") == -1)
						sql += "UPDATE " + table + " SET url_hkref='" + StringUtils.normalize(url) + "' WHERE id=" + id + ";\r\n";
				}
			}
		}
		jResult.setText(jResult.getText() + sql);
		return sql;
	}

}